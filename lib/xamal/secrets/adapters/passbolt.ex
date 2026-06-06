defmodule Xamal.Secrets.Adapters.Passbolt do
  @moduledoc false

  import Xamal.Output
  import Xamal.Secrets.Adapters.Helpers

  def fetch(args) do
    {opts, secrets, _} = OptionParser.parse(args, switches: [from: :string])
    folder = Keyword.get(opts, :from)

    if secrets == [] do
      say("Usage: mix xamal.secrets.fetch passbolt [--from FOLDER] SECRET...", :red)
    else
      Enum.each(secrets, &fetch_secret(&1, folder))
    end
  end

  defp fetch_secret(secret, folder) do
    filter_args = if folder, do: ["--filter", "folder=#{folder}"], else: []
    cmd_args = ["get", "resource", "--filter", "name=#{secret}"] ++ filter_args

    command("passbolt", cmd_args, &IO.puts/1, "Failed to fetch '#{secret}'")
  end
end
