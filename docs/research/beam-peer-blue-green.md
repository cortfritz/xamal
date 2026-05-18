# Research: BEAM Peer Node Blue-Green Deploys (FlyDeploy.BlueGreen)

## Context

Chris McCord's tweet showed `FlyDeploy.BlueGreen` — a mechanism where the Erlang VM boots the user's app inside a `:peer` node, and on deploy, swaps to a new peer node with zero-downtime using `SO_REUSEPORT`. This research explores whether this approach could replace Caddy + systemd unit swapping in Xamal.

**Assumption**: TLS is handled by Cloudflare, so we don't need Caddy for certificate management.

---

## How FlyDeploy.BlueGreen Works

### Source
- MIT licensed: [github.com/chrismccord/fly_deploy](https://github.com/chrismccord/fly_deploy)
- Key files: `lib/fly_deploy/blue_green.ex`, `lib/fly_deploy/blue_green/{peer_manager.ex, sentinel.ex, supervisor.ex}`

### Architecture

The user adds `fly_deploy` as a hex dependency and makes a small change to `Application.start/2`:

```elixir
# Before: standard Phoenix app
def start(_type, _args) do
  children = [
    {DNSCluster, query: "_app.internal"},
    MyApp.Repo,
    {Phoenix.PubSub, name: MyApp.PubSub},
    MyAppWeb.Endpoint
  ]
  Supervisor.start_link(children, strategy: :one_for_one)
end

# After: with BlueGreen
def start(type, args) do
  FlyDeploy.BlueGreen.start_link(
    [{DNSCluster, query: "_app.internal"}],        # parent-level children
    otp_app: :my_app,
    start: {__MODULE__, :start_app, [type, args]}   # peer-level boot
  )
end

def start_app(_type, _args) do
  children = [
    MyApp.Repo,
    {Phoenix.PubSub, name: MyApp.PubSub},
    MyAppWeb.Endpoint
  ]
  Supervisor.start_link(children, strategy: :one_for_one)
end
```

### Supervision tree (parent BEAM)

```
Application.start/2
  FlyDeploy.BlueGreen.Supervisor
    Parent children (DNSCluster, etc.)   -- survive deploys
    Task.Supervisor
    PeerManager                          -- boots/swaps peer nodes
    Poller                               -- watches S3 for new releases
```

The actual app (Repo, PubSub, Endpoint) runs inside a `:peer` child BEAM node managed by PeerManager.

### Deploy flow

1. Developer runs `mix fly_deploy.hot` — builds release, tars beam files, uploads to S3 (Tigris)
2. **Poller** (GenServer inside the running app) detects new tarball in S3
3. Poller tells **PeerManager** to upgrade
4. PeerManager downloads new release, boots a **new `:peer` node**
5. **`SO_REUSEPORT` is injected** (`do_inject_reuseport/2`) — new peer binds to the SAME port as old peer
6. Kernel load-balances new connections across both peers during transition
7. PeerManager arms the **Sentinel** on the old peer via `:erpc.call`
8. Old peer drains — Sentinel terminates last (first child = last to shut down in OTP)
9. `before_cutover` callback runs, state handed off via ETS on parent node
10. Old peer gone, new peer is sole listener

### Key mechanisms

- **`:peer` module** (Erlang/OTP stdlib) — boots child BEAM nodes connected via Erlang distribution
- **`SO_REUSEPORT`** (Linux kernel 3.9+) — multiple processes bind same port, kernel distributes connections
- **`:erpc.call`** — RPC between parent and peer nodes for coordination
- **ETS on parent** — handoff state storage that survives peer swaps (`put_handoff/2`, `get_handoff/1`)
- **Sentinel** — GenServer injected as first child in peer's supervisor; terminates last, runs cutover callback

### SO_REUSEPORT support in Elixir HTTP servers

- **Ranch 2.0** (Cowboy/Phoenix): `num_listen_sockets` option uses SO_REUSEPORT
- **Thousand Island** (Bandit): `transport_options: [reuseport: true]` or `[reuseport_lb: true]`

Both major Elixir HTTP servers support this natively.

### SO_REUSEPORT caveat

When the number of listeners changes (peer starting/stopping), in-flight TCP handshakes can get dropped. The kernel routes SYN packets to a specific listener socket, and if that listener disappears before the 3-way handshake completes, the connection fails. In practice this is a tiny window and clients retry transparently.

---

## What This Means for Xamal

### Current Xamal deploy flow
1. Build release, upload tarball via SCP
2. Start new systemd unit on alternate port (blue-green)
3. Health check new instance
4. Reconfigure Caddy to point at new port
5. Drain old instance, stop old systemd unit

### Potential BlueGreen-based flow (no Caddy)
1. Build release, upload tarball via SCP to known path on server
2. The running app detects new tarball (via poller or RPC trigger)
3. App boots new `:peer` node with SO_REUSEPORT on same port
4. Old peer drains and shuts down
5. Done — port never changes, no external config to update

### What would be needed

1. **A `xamal_deploy` hex package** (or fork of fly_deploy's BlueGreen modules)
   - Replace S3 Poller with local file watcher or RPC-triggered upgrade
   - Remove Fly API dependencies
   - Keep: PeerManager, Sentinel, SO_REUSEPORT injection, handoff ETS

2. **User-facing changes** (one-time)
   - Add `{:xamal_deploy, "~> 0.1"}` to mix.exs
   - Split `Application.start/2` into parent + peer sections (~5-10 lines changed)

3. **Xamal task changes**
   - Deploy command: build release, SCP tarball, trigger upgrade
   - Trigger mechanism options:
     a. **Poll local directory** — app watches e.g. `/opt/myapp/releases/` for new tarballs
     b. **Erlang RPC** — `xamal` connects via Erlang distribution and calls upgrade function
     c. **HTTP API** — app exposes internal endpoint for upgrade triggers
   - First deploy: still needs systemd unit setup (one unit, one port, forever)
   - Remove Caddy setup/management entirely (if TLS is offloaded)

### Tradeoffs

| Aspect | Current (Caddy + systemd) | BlueGreen (peer nodes) |
|--------|--------------------------|----------------------|
| User code changes | None | ~10 lines + 1 dependency |
| External dependencies | Caddy on server | None (if TLS offloaded) |
| Port management | Two ports, swap via Caddy | One port, SO_REUSEPORT |
| Systemd units | Two units, swap active | One unit, forever |
| Deploy complexity | Caddy config reload | Internal peer swap |
| Process isolation | Full OS-level isolation | Same machine, peer BEAM |
| OTP version changes | Works (separate processes) | Requires restart (can't peer across OTP versions) |
| Rollback | Start old unit, swap Caddy | Boot old release as new peer |
| State handoff | None (stateless swap) | ETS-based handoff possible |
| LiveView connections | Dropped on deploy | Potentially preserved |

### Open questions

1. **OTP version mismatches**: If a deploy changes the Elixir/OTP version, `:peer` nodes can't span versions. Need fallback to full restart.
2. **Trigger mechanism**: What's the best way for Xamal to tell the running app to upgrade? Local file polling is simplest but has latency. Erlang RPC is instant but requires distribution to be enabled.
3. **First deploy**: Still need traditional setup (upload release, create systemd unit, start). BlueGreen only helps for subsequent deploys.
4. **NIFs and ports**: If the app uses NIFs, can a peer node load different .so files? Needs investigation.
5. **Memory**: Two BEAM VMs running simultaneously during cutover — memory usage doubles briefly.

---

## References

- [FlyDeploy GitHub (MIT)](https://github.com/chrismccord/fly_deploy)
- [Ranch 2.0 - SO_REUSEPORT](https://ninenines.eu/articles/ranch-2.0.0/)
- [ThousandIsland - reuseport option](https://hexdocs.pm/thousand_island/ThousandIsland.html)
- [LWN: SO_REUSEPORT](https://lwn.net/Articles/542629/)
- [Fly.io Community: Hot code upgrades](https://community.fly.io/t/hot-code-upgrades-for-elixir-and-phoenix-apps/26389)
- [Thinking Elixir 279](https://podcast.thinkingelixir.com/279)
- [Chris McCord's tweet](https://x.com/chris_mccord/status/2029630330630508929)
