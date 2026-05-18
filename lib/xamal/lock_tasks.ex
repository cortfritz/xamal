defmodule Xamal.LockTasks do
  @moduledoc """
  Deploy lock task implementations.
  """

  import Xamal.Output
  import Xamal.Remote

  alias Xamal.Commander
  alias Xamal.Commands.Lock, as: LockCommand
  alias Xamal.LocalIdentity

  def status(args, opts), do: status(args, opts, Commander.context())

  def status(_args, _opts, context) do
    config = context.config
    cmd = LockCommand.status(config)

    case on_primary(cmd, context) do
      {:ok, output} ->
        say("Lock is held:", :yellow)
        IO.puts(output)

      {:error, _} ->
        say("No deploy lock in place", :green)
    end
  end

  def acquire(args, opts), do: acquire(args, opts, Commander.context())

  def acquire(args, _opts, context) do
    config = context.config

    {lock_opts, rest, _} =
      OptionParser.parse(args, switches: [message: :string], aliases: [m: :message])

    message =
      cond do
        Keyword.has_key?(lock_opts, :message) -> lock_opts[:message]
        rest != [] -> Enum.join(rest, " ")
        true -> "Manual lock"
      end

    on_primary(LockCommand.ensure_locks_directory(config), context)

    cmd =
      LockCommand.acquire(
        config,
        message,
        config.version,
        LocalIdentity.git_user_name(),
        DateTime.utc_now() |> DateTime.to_iso8601()
      )

    case on_primary(cmd, context) do
      {:ok, _} -> say("Deploy lock acquired", :green)
      {:error, _} -> say("Failed to acquire lock (already locked?)", :red)
    end
  end

  def release(args, opts), do: release(args, opts, Commander.context())

  def release(_args, _opts, context) do
    config = context.config
    cmd = LockCommand.release(config)

    case on_primary(cmd, context) do
      {:ok, _} ->
        say("Deploy lock released", :green)

      {:error, reason} ->
        say("Failed to release lock: #{inspect(reason)}", :red)
    end
  end
end
