defmodule Xamal.Secrets.Adapters.BitwardenSecretsManager do
  @moduledoc false

  import Xamal.Output
  import Xamal.Secrets.Adapters.Helpers

  def fetch(args) do
    {opts, secrets, _} = OptionParser.parse(args, switches: [from: :string])
    project = Keyword.get(opts, :from)

    if secrets == [] and project == nil do
      say(
        "Usage: mix xamal.secrets.fetch bitwarden_secrets_manager [--from PROJECT] SECRET_UUID...",
        :red
      )
    else
      Enum.each(secrets, &fetch_secret/1)
    end
  end

  defp fetch_secret(secret) do
    command("bws", ["secret", "get", secret], &IO.puts/1, "Failed to fetch '#{secret}'")
  end
end
