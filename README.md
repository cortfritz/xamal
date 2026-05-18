# Xamal

Xamal is an Elixir port of [Kamal](https://github.com/basecamp/kamal) — Basecamp's tool for deploying web apps anywhere. It uses Mix tasks, Elixir configuration (`config/xamal.exs`), native releases, and Caddy instead of Docker containers and kamal-proxy.

If you're familiar with Kamal, you should feel right at home. The operational model, hook system, secrets management, and destination-based multi-environment workflow carry over.

## What's different from Kamal

- **Elixir releases** instead of Docker containers — built with `mix release`, distributed as tarballs
- **Caddy** instead of kamal-proxy — automatic TLS via Let's Encrypt, zero-downtime blue-green deploys via port switching
- **Erlang SSH** instead of shelling out to `ssh` — connection pooling via GenServer
- **Mix tasks** — deploy from the same toolchain that builds your release

Docker-specific configuration (image, registry, Dockerfile, build args, etc.) is intentionally omitted since releases replace containers entirely.

## Install

Requires Erlang/OTP 26+ on the machine running xamal (the escript needs the BEAM runtime).

### One-liner

```sh
curl -fsSL https://raw.githubusercontent.com/dmkenney/xamal/master/install.sh | bash
```

This downloads the latest pre-built escript to `~/.local/bin/xamal`. Set `XAMAL_INSTALL_DIR` to change the install location, or pass a version argument:

```sh
curl -fsSL https://raw.githubusercontent.com/dmkenney/xamal/master/install.sh | bash -s v0.2.0
```

### Build from source

Requires Elixir 1.15+ in addition to Erlang/OTP 26+.

```sh
git clone https://github.com/dmkenney/xamal.git
cd xamal
mix deps.get
mix escript.build
mkdir -p ~/.local/bin
cp xamal ~/.local/bin/
```

Make sure `~/.local/bin` is on your `$PATH` (add to `~/.bashrc` or `~/.zshrc`):

```sh
export PATH="$HOME/.local/bin:$PATH"
```

### Why not `mix escript.install`?

You can also install with `mix escript.install`, which places the binary in `~/.mix/escripts/`. However, if you use [asdf](https://asdf-vm.com/) to manage Elixir versions, the escript gets registered under whichever Elixir version was active when you installed it. If you then `cd` into a project that pins a different Elixir version in `.tool-versions`, asdf's shim will refuse to run xamal. You'd need to reinstall the escript every time you switch versions.

Copying the binary directly to `~/.local/bin` avoids this entirely since it bypasses asdf's shim system. Just make sure `~/.local/bin` appears on your `$PATH` **before** asdf's shims directory.

## Quick start

```sh
# Generate config stubs and sample hooks
mix xamal.init

# Edit config/xamal.exs and .xamal/secrets, then:
mix xamal.setup
```

## Configuration

Xamal reads Elixir config from `config/xamal.exs`:

```elixir
import Config

config :xamal,
  service: "my-app",
  servers: [
    web: ["192.168.0.1", "192.168.0.2"],
    worker: [
      hosts: ["192.168.0.3"],
      cmd: ~s(bin/my_app eval "Worker.start()")
    ]
  ],
  ssh: [
    user: "deploy"
  ],
  caddy: [
    host: "app.example.com",
    app_port: 4000
  ],
  env: [
    clear: [
      PHX_HOST: "app.example.com"
    ],
    secret: ["SECRET_KEY_BASE"]
  ],
  release: [
    name: "my_app",
    mix_env: "prod"
  ],
  health_check: [
    path: "/health"
  ]
```

**Important:** The `release.name` must match a named release in your `mix.exs`. Xamal runs `mix release <name>`, which requires an explicit release definition:

```elixir
# mix.exs
def project do
  [
    ...
    releases: [
      my_app: [
        version: {:from_app, :my_app}
      ]
    ]
  ]
end
```

Without this, `mix release my_app` will fail with `Unknown release :my_app`.

Because this is Elixir config, normal Elixir expressions such as `System.get_env/1` are available.

Run `mix xamal docs <topic>` for detailed reference on any config section.

## Commands

```
mix xamal.setup               # Bootstrap servers and deploy
mix xamal.deploy              # Build, distribute, and boot
mix xamal.redeploy            # Deploy without bootstrapping
mix xamal.rollback VERSION    # Roll back to a previous version
mix xamal.app boot            # Zero-downtime restart
mix xamal.app exec CMD        # Run a command on servers
mix xamal.app.logs -f         # Tail logs
mix xamal.app maintenance     # Enable maintenance mode (503)
mix xamal.app live            # Disable maintenance mode
mix xamal.lock.status         # Check deploy lock
mix xamal secrets print       # Show secrets (redacted)
mix xamal.config              # Show merged configuration
mix xamal docs hooks          # Show hook documentation
```

## Hooks

Shell scripts in `.xamal/hooks/` that run locally at lifecycle points:

| Hook | When |
|---|---|
| `pre-build` | Before building the release |
| `post-build` | After building the release |
| `pre-deploy` | Before deploying |
| `post-deploy` | After deploying |
| `pre-app-boot` | Before booting the app |
| `post-app-boot` | After booting the app |
| `pre-caddy-reload` | Before Caddy config reload |
| `post-caddy-reload` | After Caddy config reload |

Hooks receive environment variables like `XAMAL_SERVICE`, `XAMAL_VERSION`, `XAMAL_HOSTS`, `XAMAL_PERFORMER`, etc. Run `xamal docs hooks` for the full list.

## Destinations

Multi-environment deploys work the same as Kamal:

```sh
mix xamal.deploy -d staging
mix xamal.deploy -d production
```

With override files like `config/xamal.staging.exs` and secrets in `.xamal/secrets.staging`.

## License

MIT
