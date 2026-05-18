defmodule Xamal.CLI.Main do
  @moduledoc """
  Main CLI commands: setup, deploy, redeploy, rollback, versions, details, audit, config, init, remove.
  """

  import Xamal.Shell

  alias Xamal.App
  alias Xamal.Commander
  alias Xamal.Commands.App, as: AppCommand
  alias Xamal.Commands.Auditor
  alias Xamal.Commands.Server, as: ServerCommand
  alias Xamal.Commands.Systemd
  alias Xamal.ConfigPrinter
  alias Xamal.Deployment
  alias Xamal.Init
  alias Xamal.SSH

  def setup(_args, opts), do: Deployment.setup(opts)

  def deploy(_args, opts), do: Deployment.deploy(opts)

  def redeploy(_args, opts), do: Deployment.redeploy(opts)

  def rollback(args, opts), do: Deployment.rollback(args, opts)

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

  def config(_args, _opts), do: ConfigPrinter.print()

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
end
