defmodule Xamal.LockTasks do
  @moduledoc """
  Deploy lock task implementations.
  """

  import Xamal.Output
  import Xamal.Remote

  alias Xamal.Commander
  alias Xamal.Commands.Lock, as: LockCommand
  alias Xamal.LocalIdentity

  def status(_args, _opts) do
    config = Commander.config()
    cmd = LockCommand.status(config)

    case on_primary(cmd) do
      {:ok, output} ->
        say("Lock is held:", :yellow)
        IO.puts(output)

      {:error, _} ->
        say("No deploy lock in place", :green)
    end
  end

  def acquire(args, _opts) do
    config = Commander.config()

    {lock_opts, rest, _} =
      OptionParser.parse(args, switches: [message: :string], aliases: [m: :message])

    message =
      cond do
        Keyword.has_key?(lock_opts, :message) -> lock_opts[:message]
        rest != [] -> Enum.join(rest, " ")
        true -> "Manual lock"
      end

    on_primary(LockCommand.ensure_locks_directory(config))

    cmd =
      LockCommand.acquire(
        config,
        message,
        config.version,
        LocalIdentity.git_user_name(),
        DateTime.utc_now() |> DateTime.to_iso8601()
      )

    case on_primary(cmd) do
      {:ok, _} -> say("Deploy lock acquired", :green)
      {:error, _} -> say("Failed to acquire lock (already locked?)", :red)
    end
  end

  def release(_args, _opts) do
    config = Commander.config()
    cmd = LockCommand.release(config)

    case on_primary(cmd) do
      {:ok, _} ->
        say("Deploy lock released", :green)

      {:error, reason} ->
        say("Failed to release lock: #{inspect(reason)}", :red)
    end
  end
end
