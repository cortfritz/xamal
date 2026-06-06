defmodule Xamal.Secrets.Adapters.Bitwarden do
  @moduledoc false

  import Xamal.Output
  import Xamal.Secrets.Adapters.Helpers

  def fetch(args) do
    {opts, secrets, _} = OptionParser.parse(args, switches: [account: :string])

    case Keyword.get(opts, :account) do
      nil ->
        say("Usage: mix xamal.secrets.fetch bitwarden --account EMAIL ITEM [ITEM/FIELD]...", :red)

      account ->
        with :ok <- login(account), {:ok, session} <- unlock() do
          fetch_secrets(secrets, session)
        end
    end
  end

  defp login(account) do
    case System.cmd("bw", ["login", "--check"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      _ -> command_status("bw", ["login", account, "--raw"], "Bitwarden login failed")
    end
  end

  defp unlock do
    case System.cmd("bw", ["unlock", "--raw"], stderr_to_stdout: true) do
      {session, 0} -> {:ok, String.trim(session)}
      {error, _} -> say_error("Bitwarden unlock failed", error)
    end
  end

  defp fetch_secrets(secrets, session) do
    System.cmd("bw", ["sync", "--session", session], stderr_to_stdout: true)

    Enum.each(secrets, fn secret ->
      shell_cmd(
        "bw get item '#{secret}' --session '#{session}'",
        &IO.puts/1,
        "Failed to fetch '#{secret}'"
      )
    end)
  end
end
