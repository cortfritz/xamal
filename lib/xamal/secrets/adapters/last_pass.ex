defmodule Xamal.Secrets.Adapters.LastPass do
  @moduledoc false

  import Xamal.Output
  import Xamal.Secrets.Adapters.Helpers

  def fetch(args) do
    {opts, secrets, _} = OptionParser.parse(args, switches: [account: :string])

    case Keyword.get(opts, :account) do
      nil ->
        say("Usage: mix xamal.secrets.fetch last_pass --account EMAIL SECRET...", :red)

      account ->
        with :ok <- login(account) do
          Enum.each(secrets, &fetch_secret/1)
        end
    end
  end

  defp login(account) do
    case System.cmd("lpass", ["status", "--quiet"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      _ -> command_status("lpass", ["login", account], "LastPass login failed")
    end
  end

  defp fetch_secret(secret) do
    command("lpass", ["show", "--json", secret], &IO.puts/1, "Failed to fetch '#{secret}'")
  end
end
