defmodule Xamal.SecretTasks do
  @moduledoc """
  Secret management task implementations.
  """

  import Xamal.Output

  alias Xamal.Secrets.Adapters.{
    AwsSecretsManager,
    Bitwarden,
    BitwardenSecretsManager,
    Doppler,
    GcpSecretManager,
    LastPass,
    OnePassword,
    Passbolt
  }

  @adapters %{
    "doppler" => Doppler,
    "1password" => OnePassword,
    "aws_secrets_manager" => AwsSecretsManager,
    "bitwarden" => Bitwarden,
    "bitwarden_secrets_manager" => BitwardenSecretsManager,
    "gcp_secret_manager" => GcpSecretManager,
    "last_pass" => LastPass,
    "passbolt" => Passbolt
  }

  def fetch([adapter | rest], _opts, _context) do
    case Map.fetch(@adapters, adapter) do
      {:ok, adapter_module} ->
        say("Fetching secrets via #{adapter}...", :magenta)
        adapter_module.fetch(rest)

      :error ->
        say("Unknown adapter: #{adapter}", :red)
        say("Supported: #{supported_adapters()}")
    end
  end

  def fetch([], _opts, _context) do
    say("Usage: mix xamal.secrets.fetch <adapter> [options]", :red)
  end

  def extract(args, _opts, context) do
    config = context.config

    case args do
      [key | _] ->
        value = Xamal.Secrets.fetch(config.secrets, key)
        IO.puts(value)

      [] ->
        say("Usage: mix xamal.secrets.extract <KEY>", :red)
    end
  end

  def print_secrets(_args, _opts, context) do
    config = context.config
    secrets = Xamal.Secrets.to_map(config.secrets)

    Enum.each(secrets, fn {key, value} ->
      IO.puts("#{key}=#{Xamal.Utils.maybe_redact(key, value)}")
    end)
  end

  defp supported_adapters do
    @adapters |> Map.keys() |> Enum.sort() |> Enum.join(", ")
  end
end
