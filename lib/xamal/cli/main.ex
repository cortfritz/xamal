defmodule Xamal.CLI.Main do
  @moduledoc """
  Main CLI commands: setup, deploy, redeploy, rollback, versions, details, audit, config, init, remove.
  """

  import Xamal.CLI.Base

  alias Xamal.CLI.App
  alias Xamal.CLI.Build
  alias Xamal.CLI.Prune
  alias Xamal.CLI.Server
  alias Xamal.Commander
  alias Xamal.Commands.App, as: AppCommand
  alias Xamal.Commands.Auditor
  alias Xamal.Commands.Server, as: ServerCommand
  alias Xamal.Commands.Systemd
  alias Xamal.Configuration
  alias Xamal.Init
  alias Xamal.SSH

  def setup(_args, opts) do
    ensure_clean_git!(opts)

    print_runtime(fn ->
      with_lock(fn ->
        record_audit("Setup started")

        say("Bootstrapping servers...", :magenta)
        Server.run("bootstrap", [], opts)

        do_deploy(opts)

        record_audit("Setup completed")
      end)
    end)
  end

  def deploy(_args, opts) do
    ensure_clean_git!(opts)

    config = Commander.config()
    record_audit("Deploy started", %{version: config.version})

    runtime =
      print_runtime(fn ->
        do_deploy(opts)
      end)

    record_audit("Deploy completed", %{version: config.version})
    run_hook("post-deploy", skip_hooks: Keyword.get(opts, :skip_hooks, false))
    runtime
  end

  def redeploy(_args, opts) do
    ensure_clean_git!(opts)

    config = Commander.config()
    record_audit("Redeploy started", %{version: config.version})

    runtime =
      print_runtime(fn ->
        skip_push = Keyword.get(opts, :skip_push, false)

        if skip_push do
          say("Distributing release to servers...", :magenta)
          Build.run("pull", [], opts)
        else
          say("Building and distributing release...", :magenta)
          Build.run("deliver", [], opts)
        end

        with_lock(fn ->
          run_hook("pre-deploy", skip_hooks: Keyword.get(opts, :skip_hooks, false))

          say("Booting app...", :magenta)
          App.run("boot", [], opts)
        end)
      end)

    record_audit("Redeploy completed", %{version: config.version})
    run_hook("post-deploy", skip_hooks: Keyword.get(opts, :skip_hooks, false))
    runtime
  end

  def rollback([version | _], opts) do
    record_audit("Rollback started", %{version: version})

    print_runtime(fn ->
      with_lock(fn ->
        run_rollback(version, opts)
      end)
    end)

    record_audit("Rollback completed", %{version: version})
  end

  def rollback([], opts) do
    case previous_version(Commander.config()) do
      nil ->
        IO.puts(:stderr, "No previous version found to roll back to.")
        IO.puts(:stderr, "Usage: xamal rollback [VERSION]")
        System.halt(1)

      previous ->
        say("Auto-detected previous version: #{previous}", :magenta)
        rollback([previous], opts)
    end
  end

  def details(_args, _opts) do
    config = Commander.config()
    hosts = Commander.hosts()

    Enum.each(hosts, fn host ->
      say("Host: #{host}", :magenta)

      active_port = read_active_port(host, config)

      case SSH.execute_command(host, AppCommand.details(config, active_port),
             ssh_config: config.ssh
           ) do
        {:ok, output} -> IO.puts(output)
        {:error, reason} -> say("  Error: #{inspect(reason)}", :red)
      end

      IO.puts("")
    end)
  end

  def versions(_args, _opts) do
    config = Commander.config()
    Enum.each(Commander.hosts(), &print_versions(&1, config))
  end

  def audit(_args, _opts) do
    config = Commander.config()
    hosts = Commander.hosts()

    Enum.each(hosts, fn host ->
      case SSH.execute_command(host, Auditor.reveal(config), ssh_config: config.ssh) do
        {:ok, output} -> puts_by_host(host, output)
        {:error, _} -> puts_by_host(host, "(no audit log)")
      end
    end)
  end

  def config(_args, _opts) do
    config = Commander.config()

    IO.puts("Service: #{Configuration.service(config)}")
    IO.puts("Version: #{config.version}")
    IO.puts("Destination: #{config.destination || "(none)"}")
    IO.puts("")
    IO.puts("Roles:")

    Enum.each(config.roles, fn role ->
      IO.puts("  #{role.name}: #{Enum.join(role.hosts, ", ")}")
    end)

    IO.puts("")
    IO.puts("SSH: #{config.ssh.user}@*:#{config.ssh.port}")
    IO.puts("Release: #{config.release.name} (#{config.release.mix_env})")

    if config.caddy.host do
      IO.puts("Caddy: #{config.caddy.host} -> port #{config.caddy.app_port}")
    end
  end

  def init(_args, _opts) do
    Init.run(yes: true)
  end

  def remove(_args, opts) do
    confirming("This will remove all releases and Caddy config. Are you sure?", opts, fn ->
      config = Commander.config()

      with_lock(fn ->
        record_audit("Remove started")

        say("Stopping app...", :magenta)
        App.run("stop", [], opts)

        say("Removing systemd units...", :magenta)
        on_hosts(Systemd.disable_all(config))
        on_hosts(Systemd.remove_unit(config))

        say("Removing service directory...", :magenta)
        on_hosts(ServerCommand.remove_service_directory(config))

        record_audit("Remove completed")
        say("Removed!", :green)
      end)
    end)
  end

  # Private

  defp print_versions(host, config) do
    say("Host: #{host}", :magenta)
    host_versions = host_releases(host, config)
    current = host_current_version(host, config)
    Enum.each(version_lines(host_versions, current), &IO.puts/1)
    IO.puts("")
  end

  defp host_releases(host, config) do
    case SSH.execute_command(host, AppCommand.list_releases(config), ssh_config: config.ssh) do
      {:ok, output} -> output |> String.trim() |> String.split("\n", trim: true)
      {:error, _} -> []
    end
  end

  defp host_current_version(host, config) do
    case SSH.execute_command(host, AppCommand.current_version(config), ssh_config: config.ssh) do
      {:ok, output} -> String.trim(output)
      {:error, _} -> nil
    end
  end

  defp version_lines([], _current), do: ["  (no releases)"]

  defp version_lines(releases, current) do
    Enum.map(releases, fn version ->
      marker = if version == current, do: " (current)", else: ""
      "  #{version}#{marker}"
    end)
  end

  defp run_rollback(version, opts) do
    config = Commander.config()
    say("Rolling back to version #{version}...", :magenta)
    run_hook("pre-deploy", skip_hooks: Keyword.get(opts, :skip_hooks, false))
    Enum.each(Commander.roles(), &rollback_role(config, &1, version))
    run_hook("post-deploy", skip_hooks: Keyword.get(opts, :skip_hooks, false))
  end

  defp rollback_role(config, role, version) do
    Enum.each(role.hosts, fn host ->
      say("  Rolling back #{host} (#{role.name})...", :magenta)
      do_rollback_host(config, role, host, version)
    end)
  end

  defp previous_version(config) do
    releases = releases(config)
    current = current_version(config)

    case Enum.drop_while(releases, &(&1 != current)) do
      [_current, previous | _] -> previous
      _ -> nil
    end
  end

  defp releases(config) do
    case on_primary(AppCommand.list_releases(config)) do
      {:ok, output} -> output |> String.trim() |> String.split("\n", trim: true)
      {:error, _} -> []
    end
  end

  defp current_version(config) do
    case on_primary(AppCommand.current_version(config)) do
      {:ok, output} -> String.trim(output)
      {:error, _} -> nil
    end
  end

  defp do_deploy(opts) do
    skip_push = Keyword.get(opts, :skip_push, false)

    if skip_push do
      say("Distributing release to servers...", :magenta)
      Build.run("pull", [], opts)
    else
      say("Building and distributing release...", :magenta)
      Build.run("deliver", [], opts)
    end

    with_lock(fn ->
      run_hook("pre-deploy", skip_hooks: Keyword.get(opts, :skip_hooks, false))

      say("Booting app on servers...", :magenta)
      App.run("boot", [], opts)

      say("Pruning old releases...", :magenta)
      Prune.prune([], opts)
    end)
  end

  defp do_rollback_host(config, _role, host, version) do
    new_port = blue_green_swap(host, config, version)
    say("  Rolled back #{host} to #{version} (port #{new_port})", :green)
  end
end
