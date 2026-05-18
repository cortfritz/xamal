defmodule Xamal.Secrets.Adapters.AwsSecretsManager do
  @moduledoc false

  import Xamal.Output
  import Xamal.Secrets.Adapters.Helpers

  def fetch(args) do
    {opts, secrets, _} = OptionParser.parse(args, switches: [from: :string, profile: :string])
    prefix = Keyword.get(opts, :from, "")
    profile = Keyword.get(opts, :profile)

    secret_ids =
      Enum.map(secrets, fn secret -> if prefix != "", do: "#{prefix}/#{secret}", else: secret end)

    if secret_ids == [] do
      say(
        "Usage: mix xamal.secrets.fetch aws_secrets_manager [--from PREFIX] [--profile PROFILE] SECRET...",
        :red
      )
    else
      fetch_secrets(secret_ids, profile)
    end
  end

  defp fetch_secrets(secret_ids, profile) do
    id_args = Enum.flat_map(secret_ids, fn id -> ["--secret-id-list", id] end)
    profile_args = if profile, do: ["--profile", profile], else: []

    command(
      "aws",
      ["secretsmanager", "batch-get-secret-value"] ++ id_args ++ profile_args,
      &IO.puts/1,
      "AWS Secrets Manager fetch failed"
    )
  end
end
