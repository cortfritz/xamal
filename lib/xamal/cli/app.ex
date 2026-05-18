defmodule Xamal.CLI.App do
  @moduledoc """
  CLI commands for managing the application.
  """

  import Xamal.CLI.Base

  alias Xamal.{Commander, Configuration, EnvFile, SSH}
  alias Xamal.Commands.App, as: AppCommand
  alias Xamal.Commands.Base, as: CommandBase
  alias Xamal.Commands.Caddy
  alias Xamal.Commands.Server
  alias Xamal.Commands.Systemd

  @commands %{
    "boot" => :boot,
    "start" => :start,
    "stop" => :stop,
    "exec" => :exec,
    "logs" => :logs,
    "details" => :details,
    "version" => :version,
    "remove" => :remove,
    "releases" => :releases,
    "stale_releases" => :stale_releases,
    "maintenance" => :maintenance,
    "live" => :live
  }

  def run(subcommand, args, opts) do
    case Map.get(@commands, subcommand) do
      nil -> say("Unknown app command: #{subcommand}", :red)
      command -> apply(__MODULE__, command, [args, opts])
    end
  end

  def boot(_args, opts) do
    config = Commander.config()
    skip_hooks = Keyword.get(opts, :skip_hooks, false)

    run_hook("pre-app-boot", skip_hooks: skip_hooks)
    Enum.each(Commander.roles(), &boot_role(&1, config, skip_hooks))
    run_hook("post-app-boot", skip_hooks: skip_hooks)
  end

  def start(_args, _opts) do
    config = Commander.config()
    hosts = Commander.hosts()

    Enum.each(hosts, fn host ->
      active_port = read_active_port(host, config) || config.caddy.app_port
      say("  Starting on #{host} (port #{active_port})...", :magenta)
      cmd = Systemd.start(config, active_port)
      execute_on(host, cmd, config)
    end)
  end

  def stop(_args, _opts) do
    config = Commander.config()
    hosts = Commander.hosts()

    Enum.each(hosts, fn host ->
      say("  Stopping on #{host}...", :magenta)
      cmd = Systemd.stop_all(config)

      case SSH.execute_command(host, cmd, ssh_config: config.ssh) do
        {:ok, _} -> say("  Stopped on #{host}", :green)
        {:error, _} -> say("  App not running on #{host}", :yellow)
      end
    end)
  end

  def exec(args, _opts) do
    config = Commander.config()
    hosts = Commander.hosts()
    {exec_opts, command} = parse_exec(args)

    if Keyword.get(exec_opts, :interactive, false) do
      interactive_exec(hd(hosts), config, command)
    else
      Enum.each(hosts, &remote_exec(&1, config, command))
    end
  end

  def logs(args, _opts) do
    config = Commander.config()
    log_opts = parse_log_opts(args)

    # For follow mode, resolve the active port for the first host
    log_opts =
      if Keyword.get(log_opts, :follow, false) do
        host = hd(Commander.hosts())
        active_port = read_active_port(host, config)
        if active_port, do: Keyword.put(log_opts, :port, active_port), else: log_opts
      else
        log_opts
      end

    dispatch_logs(log_opts, &AppCommand.logs(config, &1), config)
  end

  def details(_args, _opts) do
    config = Commander.config()
    hosts = Commander.hosts()

    Enum.each(hosts, fn host ->
      active_port = read_active_port(host, config)
      cmd = AppCommand.details(config, active_port)

      case SSH.execute_command(host, cmd, ssh_config: config.ssh) do
        {:ok, output} -> puts_by_host(host, output)
        {:error, _} -> puts_by_host(host, "(not available)")
      end
    end)
  end

  def version(_args, _opts) do
    config = Commander.config()
    hosts = Commander.hosts()

    Enum.each(hosts, fn host ->
      cmd = AppCommand.current_version(config)

      case SSH.execute_command(host, cmd, ssh_config: config.ssh) do
        {:ok, output} -> puts_by_host(host, output, type: "Version")
        {:error, _} -> puts_by_host(host, "(unknown)")
      end
    end)
  end

  def remove(_args, opts) do
    confirming("This will remove all releases. Are you sure?", opts, fn ->
      stop([], opts)
      config = Commander.config()
      Enum.each(Commander.hosts(), &remove_host_releases(&1, config))
    end)
  end

  def releases(_args, _opts) do
    config = Commander.config()
    hosts = Commander.hosts()

    Enum.each(hosts, fn host ->
      cmd = AppCommand.list_releases(config)

      case SSH.execute_command(host, cmd, ssh_config: config.ssh) do
        {:ok, output} -> puts_by_host(host, output, type: "Releases")
        {:error, _} -> puts_by_host(host, "(none)")
      end
    end)
  end

  def stale_releases(_args, _opts) do
    config = Commander.config()
    keep = Configuration.retain_releases(config)
    hosts = Commander.hosts()

    Enum.each(hosts, fn host ->
      cmd = AppCommand.stale_releases(config, keep)

      case SSH.execute_command(host, cmd, ssh_config: config.ssh) do
        {:ok, output} -> puts_by_host(host, output, type: "Stale Releases")
        {:error, _} -> puts_by_host(host, "(none)")
      end
    end)
  end

  def maintenance(_args, opts) do
    config = Commander.config()
    hosts = Commander.hosts()
    skip_hooks = Keyword.get(opts, :skip_hooks, false)

    say("Enabling maintenance mode...", :magenta)

    run_hook("pre-caddy-reload", skip_hooks: skip_hooks)

    Enum.each(hosts, fn host ->
      cmd = Caddy.write_maintenance_caddyfile(config)
      SSH.execute_command(host, cmd, ssh_config: config.ssh)
      SSH.execute_command(host, Caddy.reload(config), ssh_config: config.ssh)
      say("  Maintenance mode enabled on #{host}", :green)
    end)

    run_hook("post-caddy-reload", skip_hooks: skip_hooks)
  end

  def live(_args, opts) do
    config = Commander.config()
    hosts = Commander.hosts()
    skip_hooks = Keyword.get(opts, :skip_hooks, false)

    say("Disabling maintenance mode...", :magenta)

    run_hook("pre-caddy-reload", skip_hooks: skip_hooks)

    Enum.each(hosts, fn host ->
      active_port = read_active_port(host, config) || config.caddy.app_port

      cmd = Caddy.write_caddyfile(config, active_port)
      SSH.execute_command(host, cmd, ssh_config: config.ssh)
      SSH.execute_command(host, Caddy.reload(config), ssh_config: config.ssh)
      say("  Live mode restored on #{host} (port #{active_port})", :green)
    end)

    run_hook("post-caddy-reload", skip_hooks: skip_hooks)
  end

  def help do
    IO.puts("""
    Usage: xamal app <command>

    Commands:
      boot              Start app (or restart with zero-downtime)
      start             Start existing release
      stop              Stop release
      exec [-i] CMD     Run command in release context
      logs [-f] [-n N]  Show logs (journalctl)
      details           Show running release info
      version           Show running version
      remove            Stop and remove release directories
      releases          List release directories
      stale_releases    List old (prunable) releases
      maintenance       Enable maintenance mode (503 responses)
      live              Disable maintenance mode (restore traffic)
    """)
  end

  # Private

  defp boot_role(role, config, skip_hooks) do
    role
    |> host_batches(config.boot)
    |> Enum.with_index()
    |> Enum.each(fn {batch, index} -> boot_batch(batch, index, role, config, skip_hooks) end)
  end

  defp host_batches(role, boot_config) do
    case Configuration.Boot.resolved_limit(boot_config, length(role.hosts)) do
      nil -> [role.hosts]
      limit -> Enum.chunk_every(role.hosts, limit)
    end
  end

  defp boot_batch(batch, index, role, config, skip_hooks) do
    maybe_wait_before_batch(index, config.boot.wait)

    Enum.each(batch, fn host ->
      say("  Booting #{role.name} on #{host}...", :magenta)
      do_boot_host(config, role, host, skip_hooks)
    end)
  end

  defp maybe_wait_before_batch(index, wait) when index > 0 and not is_nil(wait) do
    say("  Waiting #{wait}s before next batch...", :magenta)
    Process.sleep(wait * 1000)
  end

  defp maybe_wait_before_batch(_index, _wait), do: :ok

  defp parse_exec(args) do
    {exec_opts, cmd_args, _invalid} =
      OptionParser.parse(args, switches: [interactive: :boolean], aliases: [i: :interactive])

    {exec_opts, Enum.join(cmd_args, " ")}
  end

  defp interactive_exec(host, config, command) do
    active_port = read_active_port(host, config)
    cmd = AppCommand.exec(config, command, interactive: true, port: active_port)

    say("Connecting to #{host}...", :magenta)
    SSH.interactive_exec(host, CommandBase.to_command_string(cmd), ssh_config: config.ssh)
  end

  defp remote_exec(host, config, command) do
    active_port = read_active_port(host, config)
    cmd = AppCommand.exec(config, command, port: active_port)

    case SSH.execute_command(host, cmd, ssh_config: config.ssh) do
      {:ok, output} -> puts_by_host(host, output)
      {:error, reason} -> puts_by_host(host, "Error: #{inspect(reason)}")
    end
  end

  defp remove_host_releases(host, config) do
    case SSH.execute_command(host, Server.remove_service_directory(config),
           ssh_config: config.ssh
         ) do
      {:ok, _} -> say("  Removed releases on #{host}", :green)
      {:error, reason} -> say("  Error on #{host}: #{inspect(reason)}", :red)
    end
  end

  defp do_boot_host(config, role, host, skip_hooks) do
    upload_env_file(host, config, role)

    new_port =
      blue_green_swap(host, config, config.version,
        skip_hooks: skip_hooks,
        rollback_version: current_version(host, config)
      )

    say("  Booted #{role.name} on #{host} (port #{new_port})", :green)
  end

  defp current_version(host, config) do
    case ssh_exec(host, AppCommand.current_version(config), config) do
      {:ok, version} -> String.trim(version)
      {:error, _} -> nil
    end
  end

  defp upload_env_file(host, config, role) do
    env = Configuration.Role.resolved_env(role, config.env)
    env_content = EnvFile.encode(Configuration.Env.to_map(env))
    env_path = Configuration.Role.secrets_path(role, config)

    ssh_exec(host, CommandBase.make_directory(Path.dirname(env_path)), config)
    ssh_exec(host, CommandBase.write([["echo", "'#{env_content}'"], [env_path]]), config)
    ssh_exec(host, Systemd.write_env_symlink(config, role), config)
  end

  defp execute_on(host, cmd, config) do
    case SSH.execute_command(host, cmd, ssh_config: config.ssh) do
      {:ok, output} -> if output != "", do: IO.puts(output)
      {:error, reason} -> say("Error on #{host}: #{inspect(reason)}", :red)
    end
  end
end
