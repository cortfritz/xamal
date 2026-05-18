defmodule Xamal.Server do
  @moduledoc """
  Server task implementations.
  """

  import Xamal.Shell

  alias Xamal.{Commander, SSH}
  alias Xamal.Commands.{Caddy, Server, Systemd}

  def run(subcommand, args, opts) do
    case subcommand do
      "exec" -> exec(args, opts)
      "bootstrap" -> bootstrap(args, opts)
      "logs" -> logs(args, opts)
      other -> say("Unknown server command: #{other}", :red)
    end
  end

  def exec(args, _opts) do
    command = Enum.join(args, " ")

    if command == "" do
      say("Usage: mix xamal.server.exec COMMAND", :red)
    else
      exec_on_hosts(command, Commander.config(), Commander.hosts())
    end
  end

  defp exec_on_hosts(command, config, hosts) do
    Enum.each(hosts, fn host ->
      case SSH.execute(host, command, ssh_config: config.ssh) do
        {:ok, output} -> puts_by_host(host, output, type: "Server")
        {:error, reason} -> puts_by_host(host, "Error: #{inspect(reason)}", type: "Server")
      end
    end)
  end

  def bootstrap(_args, _opts) do
    config = Commander.config()
    hosts = Commander.hosts()

    say("Bootstrapping #{length(hosts)} server(s)...", :magenta)

    Enum.each(hosts, fn host ->
      say("  Bootstrapping #{host}...", :magenta)

      # Check if Caddy is installed
      case SSH.execute_command(host, Caddy.check_installed(), ssh_config: config.ssh) do
        {:ok, _} ->
          say("  Caddy already installed on #{host}", :green)

        {:error, _} ->
          say("  Installing Caddy on #{host}...", :magenta)
          install_cmd = Caddy.install()
          SSH.execute_command(host, install_cmd, ssh_config: config.ssh, timeout: 120_000)
      end

      # Create directory structure
      bootstrap_cmd = Server.bootstrap(config)
      SSH.execute_command(host, bootstrap_cmd, ssh_config: config.ssh)

      # Install systemd service unit
      say("  Installing systemd service unit on #{host}...", :magenta)

      SSH.execute_command(host, Systemd.install_unit(config), ssh_config: config.ssh)

      # Generate initial Caddyfile
      caddyfile_cmd = Caddy.write_caddyfile(config, config.caddy.app_port)
      SSH.execute_command(host, caddyfile_cmd, ssh_config: config.ssh)

      # Point system Caddyfile to import service Caddyfiles (survives reboot)
      SSH.execute_command(host, Caddy.configure_system_caddyfile(), ssh_config: config.ssh)

      # Start/reload Caddy
      SSH.execute_command(host, Caddy.reload(config), ssh_config: config.ssh)

      say("  Bootstrapped #{host}", :green)
    end)
  end

  def logs(args, _opts) do
    config = Commander.config()
    log_opts = parse_log_opts(args)

    dispatch_logs(log_opts, &Caddy.logs/1, config, type: "Server")
  end

  def help do
    IO.puts("""
    Use `mix help | grep xamal.server` to list server tasks.

    Commands:
      exec CMD          Run arbitrary command via SSH on all servers
      bootstrap         Install Caddy and setup directories
      logs [-f] [-n N]  Show Caddy proxy logs (journalctl)
    """)
  end
end
