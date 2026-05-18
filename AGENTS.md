# Agents

## Project

Xamal is a Mix-first Elixir deployment tool for bare-metal Elixir releases over SSH. It is inspired by Kamal, but uses native releases, Caddy, and Elixir configuration instead of Docker, kamal-proxy, and YAML.

## Stack

- Elixir 1.15+, OTP 26+
- Mix tasks (`mix xamal.*`) are the public command surface
- Elixir config via `config/xamal.exs`
- Destination overrides live under `config/xamal/<destination>.exs`
- SSH via Erlang `:ssh` stdlib
- Tests: `mix test` (ExUnit)
- Quality checks: `mix ci`

## Architecture

- `lib/mix/tasks/` — public Mix task entrypoints
- `lib/xamal/deployment.ex` — high-level deploy/redeploy/setup/rollback orchestration
- `lib/xamal/app.ex`, `build.ex`, `server.ex`, `lock.ex`, `prune.ex`, `secrets.ex`, `docs.ex` — command implementations used by Mix tasks
- `lib/xamal/shell.ex` — shell/UI helpers, SSH execution helpers, hooks, lock handling, blue-green boot flow
- `lib/xamal/commands/` — pure functions returning command lists (`["cmd", "arg1"]`), composed with `combine/pipe/chain`
- `lib/xamal/configuration/` — structs with `new/1` constructors parsing Elixir config data
- `lib/xamal/context.ex` — explicit runtime context for config, host/role filters, verbosity, lock, and connection state
- `lib/xamal/commander.ex` — compatibility Agent wrapper around `Xamal.Context`

## Conventions

- Prefer Mix tasks over custom CLI dispatch.
- Do not add an escript entrypoint.
- Do not introduce `Xamal.CLI.*` modules; command behavior belongs in `Xamal.*` modules or Mix tasks.
- Command builder modules return list-of-strings and never execute anything.
- Config structs are immutable and built from Elixir config.
- Hooks run locally, not on remote servers.
- Run `mix ci` before considering a change complete.

## Commit messages

- No AI attribution in commit messages — no "Co-Authored-By", no mentioning Claude, Copilot, ChatGPT, or any AI tool
- Keep messages short and descriptive
- Use imperative mood ("Add feature" not "Added feature")
