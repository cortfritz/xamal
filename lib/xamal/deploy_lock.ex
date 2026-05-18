defmodule Xamal.DeployLock do
  @moduledoc false

  import Xamal.Output
  import Xamal.Remote

  alias Xamal.Commander
  alias Xamal.Commands.Lock

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

  defp acquire_lock do
    config = Commander.config()

    say("Acquiring the deploy lock...", :magenta)
    on_primary(Lock.ensure_locks_directory(config))

    case on_primary(Lock.acquire(config, "Automatic deploy lock", config.version)) do
      {:ok, _} ->
        Commander.set_holding_lock(true)

      {:error, {:ssh_connection_failed, hostname, port, reason}} ->
        say("SSH connection failed to #{hostname}:#{port} (#{reason})", :red)
        say("Verify the host is reachable and SSH is running.", :red)
        raise "SSH connection failed to #{hostname}:#{port}"

      {:error, _reason} ->
        say("Deploy lock already in place!", :red)
        print_lock_status(config)
        raise "Deploy lock found. Run 'mix xamal.lock.status' for more information"
    end
  end

  defp print_lock_status(config) do
    case on_primary(Lock.status(config)) do
      {:ok, output} -> IO.puts(output)
      _ -> :ok
    end
  end

  defp release_lock do
    config = Commander.config()
    say("Releasing the deploy lock...", :magenta)

    on_primary(Lock.release(config))
    Commander.set_holding_lock(false)
  end
end
