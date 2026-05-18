defmodule Xamal.CLI.Base do
  @moduledoc """
  Shared CLI behavior: lock management, hooks, output, timing.
  """

  alias IO.ANSI
  alias Xamal.{Commander, HealthCheck, SSH}
  alias Xamal.Commands.{Auditor, Base, Caddy, Hook, Lock, Server, Systemd}
  alias Xamal.Configuration

  @doc """
  Print a status message.
  """
  def say(message, color \\ :default) do
    message
    |> colorize(color)
    |> IO.puts()
  end

  defp colorize(message, :default), do: message
  defp colorize(message, color), do: ANSI.format([color, message], true)

  @doc """
  Print output with host prefix.
  """
  def puts_by_host(host, output, opts \\ []) do
    type = Keyword.get(opts, :type, "App")
    quiet = Keyword.get(opts, :quiet, false)

    unless quiet do
      say("#{type} Host: #{host}")
    end

    IO.puts("#{output}\n")
  end

  @doc """
  Abort if the git working tree is dirty, unless --skip-dirty-check is passed.
  """
  def ensure_clean_git!(opts) do
    unless Keyword.get(opts, :skip_dirty_check, false) do
      if Xamal.Utils.git_dirty?() do
        say("Deploy aborted: uncommitted changes detected.", :red)
        say("Commit your changes or use --skip-dirty-check to deploy anyway.", :yellow)
        System.halt(1)
      end
    end
  end

  @doc """
  Execute a block with timing and print the runtime.
  """
  def print_runtime(fun) do
    started_at = System.monotonic_time(:millisecond)
    result = fun.()
    elapsed = (System.monotonic_time(:millisecond) - started_at) / 1000
    say("  Finished all in #{:erlang.float_to_binary(elapsed, decimals: 1)} seconds")
    result
  end

  @doc """
  Execute with deploy lock. Acquires lock, runs function, releases lock.
  """
  def with_lock(fun) do
    if Commander.holding_lock?() do
      fun.()
    else
      acquire_lock()

      try do
        result = fun.()
        release_lock()
        result
      rescue
        e ->
          try do
            release_lock()
          rescue
            lock_err -> say("Error releasing deploy lock: #{Exception.message(lock_err)}", :red)
          end

          reraise e, __STACKTRACE__
      end
    end
  end

  @doc """
  Ask for confirmation before proceeding.
  """
  def confirming(question, opts, fun) do
    if Keyword.get(opts, :confirmed, false) do
      fun.()
    else
      IO.write("#{question} [y/N] ")

      case IO.gets("") |> String.trim() |> String.downcase() do
        "y" -> fun.()
        _ -> say("Aborted", :red)
      end
    end
  end

  @doc """
  Run a hook script if it exists and hooks aren't skipped.
  """
  def run_hook(hook_name, opts \\ []) do
    skip = Keyword.get(opts, :skip_hooks, false)
    config = Commander.config()

    if !skip && config && Hook.hook_exists?(config, hook_name) do
      say("Running hook #{hook_name}...", :magenta)

      hook_cmd = Hook.run(config, hook_name)
      hook_env = Hook.env(config, Map.new(Keyword.get(opts, :details, [])))

      env_pairs = Enum.map(hook_env, fn {k, v} -> {to_string(k), to_string(v)} end)

      case System.cmd("sh", ["-c", Enum.join(hook_cmd, " ")],
             env: env_pairs,
             stderr_to_stdout: true
           ) do
        {output, 0} ->
          if output != "", do: IO.puts(output)
          :ok

        {output, code} ->
          say("Hook '#{hook_name}' failed (exit #{code}):", :red)
          IO.puts(output)
          raise "Hook `#{hook_name}` failed"
      end
    end
  end

  @doc """
  Execute a command on the primary host.
  """
  def on_primary(command_parts) do
    config = Commander.config()
    host = Commander.primary_host()
    SSH.execute_command(host, command_parts, ssh_config: config.ssh)
  end

  @doc """
  Execute a command on all filtered hosts.
  """
  def on_hosts(command_parts) do
    config = Commander.config()
    hosts = Commander.hosts()

    SSH.on(hosts, fn host ->
      SSH.execute_command(host, command_parts, ssh_config: config.ssh)
    end)
  end

  @doc """
  Record an audit log entry on the primary host.
  """
  def record_audit(message, details \\ %{}) do
    config = Commander.config()

    if config do
      cmd = Auditor.record(config, message, details)
      on_primary(cmd)
    end
  end

  @doc """
  Read the active port from a remote host. Returns the port integer or nil.
  """
  def read_active_port(host, config) do
    case SSH.execute_command(host, Caddy.read_active_port(config), ssh_config: config.ssh) do
      {:ok, port_str} ->
        case Integer.parse(String.trim(port_str)) do
          {port, _} -> port
          :error -> nil
        end

      {:error, _} ->
        nil
    end
  end

  @doc """
  Execute a command on a single host. Shorthand for SSH.execute_command.
  """
  def ssh_exec(host, cmd, config) do
    SSH.execute_command(host, cmd, ssh_config: config.ssh)
  end

  @doc """
  Perform a blue-green deploy swap on a single host.

  Handles: port selection, symlink, systemd start, health check (with rollback
  on failure), Caddy update, drain, stop old, enable/disable, active port write.

  Options:
    - :skip_hooks — skip caddy reload hooks (default: true)
    - :rollback_version — version to revert symlink to on health check failure
  """
  def blue_green_swap(host, config, version, opts \\ []) do
    app_port = config.caddy.app_port
    alt_port = Configuration.Caddy.alt_port(config.caddy)
    hc = config.health_check
    skip_hooks = Keyword.get(opts, :skip_hooks, true)

    active_port = read_active_port(host, config) || app_port
    new_port = if active_port == app_port, do: alt_port, else: app_port

    # Update current symlink BEFORE start (systemd unit references it)
    ssh_exec(host, Server.link_current(config, version), config)

    # Start new release via systemd
    ssh_exec(host, Systemd.start(config, new_port), config)

    # Wait for readiness via health check
    delay = Configuration.readiness_delay(config)
    say("  Waiting for health check (#{hc.path}, timeout #{hc.timeout}s)...", :magenta)
    Process.sleep(delay * 1000)

    case HealthCheck.wait_until_ready_remote(host, new_port, config,
           path: hc.path,
           interval: hc.interval,
           timeout: hc.timeout
         ) do
      :ok ->
        say("  Health check passed on #{host}:#{new_port}", :green)

      {:error, :timeout} ->
        say("  Health check timed out on #{host}:#{new_port}!", :red)
        ssh_exec(host, Systemd.stop(config, new_port), config)

        if rollback_version = Keyword.get(opts, :rollback_version) do
          ssh_exec(host, Server.link_current(config, rollback_version), config)
        end

        raise "Health check failed for #{host} after #{hc.timeout}s"
    end

    # Update Caddy to point to new port
    run_hook("pre-caddy-reload", skip_hooks: skip_hooks)
    ssh_exec(host, Caddy.write_caddyfile(config, new_port), config)
    ssh_exec(host, Caddy.reload(config), config)
    run_hook("post-caddy-reload", skip_hooks: skip_hooks)

    # Stop old release (systemd TimeoutStopSec handles drain)
    if active_port != new_port do
      drain = Configuration.drain_timeout(config)
      say("  Stopping old release (#{drain}s drain timeout)...", :magenta)
      ssh_exec(host, Systemd.stop(config, active_port), config)
    end

    # Enable new instance, disable old
    ssh_exec(host, Systemd.enable(config, new_port), config)

    if active_port != new_port do
      ssh_exec(host, Systemd.disable(config, active_port), config)
    end

    # Write active port
    ssh_exec(host, Caddy.write_active_port(config, new_port), config)

    new_port
  end

  @doc """
  Parse standard log options from CLI args.
  """
  def parse_log_opts(args) do
    {log_opts, _, _} =
      OptionParser.parse(args,
        switches: [since: :string, lines: :integer, grep: :string, follow: :boolean],
        aliases: [n: :lines, f: :follow]
      )

    log_opts
  end

  @doc """
  Dispatch log command with follow/batch pattern.

  The `build_cmd` function receives log_opts and returns a command list.
  Options: :type for puts_by_host label (default "App").
  """
  def dispatch_logs(log_opts, build_cmd, config, opts \\ []) do
    hosts = Commander.hosts()
    type = Keyword.get(opts, :type, "App")
    follow = Keyword.get(log_opts, :follow, false)

    if follow do
      host = hd(hosts)
      cmd = build_cmd.(log_opts)

      SSH.streaming_exec(host, Base.to_command_string(cmd), ssh_config: config.ssh)
    else
      Enum.each(hosts, fn host ->
        cmd = build_cmd.(log_opts)

        case SSH.execute_command(host, cmd, ssh_config: config.ssh) do
          {:ok, output} -> puts_by_host(host, output, type: type)
          {:error, _} -> puts_by_host(host, "(no logs available)", type: type)
        end
      end)
    end
  end

  defp acquire_lock do
    config = Commander.config()

    say("Acquiring the deploy lock...", :magenta)

    on_primary(Lock.ensure_locks_directory(config))

    lock_cmd = Lock.acquire(config, "Automatic deploy lock", config.version)

    case on_primary(lock_cmd) do
      {:ok, _} ->
        Commander.set_holding_lock(true)

      {:error, {:ssh_connection_failed, hostname, port, reason}} ->
        say("SSH connection failed to #{hostname}:#{port} (#{reason})", :red)
        say("Verify the host is reachable and SSH is running.", :red)
        raise "SSH connection failed to #{hostname}:#{port}"

      {:error, _reason} ->
        say("Deploy lock already in place!", :red)

        case on_primary(Lock.status(config)) do
          {:ok, output} -> IO.puts(output)
          _ -> :ok
        end

        raise "Deploy lock found. Run 'xamal lock --help' for more information"
    end
  end

  defp release_lock do
    config = Commander.config()
    say("Releasing the deploy lock...", :magenta)

    on_primary(Lock.release(config))
    Commander.set_holding_lock(false)
  end
end
