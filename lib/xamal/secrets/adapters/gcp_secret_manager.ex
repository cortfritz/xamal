defmodule Xamal.Secrets.Adapters.GcpSecretManager do
  @moduledoc false

  import Xamal.Output
  import Xamal.Secrets.Adapters.Helpers

  def fetch(args) do
    {opts, secrets, _} = OptionParser.parse(args, switches: [account: :string, from: :string])

    if secrets == [] do
      say(
        "Usage: mix xamal.secrets.fetch gcp_secret_manager [--account USER] [--from PROJECT] SECRET...",
        :red
      )
    else
      Enum.each(secrets, &fetch_secret(&1, opts))
    end
  end

  defp fetch_secret(secret, opts) do
    {project, name, version} = secret_parts(secret, Keyword.get(opts, :from))
    project_arg = if project, do: ["--project", project], else: []

    impersonate =
      if account = Keyword.get(opts, :account),
        do: ["--impersonate-service-account", account],
        else: []

    command(
      "gcloud",
      ["secrets", "versions", "access", version, "--secret", name] ++ project_arg ++ impersonate,
      fn output -> IO.puts(String.trim(output)) end,
      "Failed to fetch '#{secret}'"
    )
  end

  defp secret_parts(secret, default_project) do
    case String.split(secret, "/") do
      [project, name, version] -> {project, name, version}
      [project, name] -> {project, name, "latest"}
      [name] -> {default_project, name, "latest"}
    end
  end
end
