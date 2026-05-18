defmodule Xamal.SecretCommands do
  @moduledoc """
  Secret management task implementations.
  """

  import Xamal.Shell

  def run(subcommand, args, opts) do
    case subcommand do
      "fetch" -> fetch(args, opts)
      "extract" -> extract(args, opts)
      "print" -> print_secrets(args, opts)
      other -> say("Unknown secrets command: #{other}", :red)
    end
  end

  @adapters %{
    "doppler" => &__MODULE__.fetch_doppler/1,
    "1password" => &__MODULE__.fetch_1password/1,
    "aws_secrets_manager" => &__MODULE__.fetch_aws_sm/1,
    "bitwarden" => &__MODULE__.fetch_bitwarden/1,
    "bitwarden_secrets_manager" => &__MODULE__.fetch_bitwarden_sm/1,
    "gcp_secret_manager" => &__MODULE__.fetch_gcp_sm/1,
    "last_pass" => &__MODULE__.fetch_lastpass/1,
    "passbolt" => &__MODULE__.fetch_passbolt/1
  }

  def fetch([adapter | rest], _opts) do
    case Map.fetch(@adapters, adapter) do
      {:ok, fetcher} ->
        say("Fetching secrets via #{adapter}...", :magenta)
        fetcher.(rest)

      :error ->
        say("Unknown adapter: #{adapter}", :red)
        say("Supported: #{supported_adapters()}")
    end
  end

  def fetch([], _opts) do
    say("Usage: mix xamal.secrets.fetch <adapter> [options]", :red)
  end

  def extract(args, _opts) do
    config = Xamal.Commander.config()

    case args do
      [key | _] ->
        value = Xamal.Secrets.fetch(config.secrets, key)
        IO.puts(value)

      [] ->
        say("Usage: mix xamal.secrets.extract <KEY>", :red)
    end
  end

  def print_secrets(_args, _opts) do
    config = Xamal.Commander.config()
    secrets = Xamal.Secrets.to_map(config.secrets)

    Enum.each(secrets, fn {key, value} ->
      IO.puts("#{key}=#{Xamal.Utils.maybe_redact(key, value)}")
    end)
  end

  def help do
    IO.puts("""
    Use `mix help | grep xamal.secrets` to list secrets tasks.

    Commands:
      fetch ADAPTER   Fetch secrets from external adapter
      extract KEY     Extract a single secret value
      print           Print all secrets (sensitive values redacted)

    Adapters:
      1password                  1Password (op CLI)
      aws_secrets_manager        AWS Secrets Manager (aws CLI)
      bitwarden                  Bitwarden (bw CLI)
      bitwarden_secrets_manager  Bitwarden Secrets Manager (bws CLI)
      doppler                    Doppler (doppler CLI)
      gcp_secret_manager         Google Cloud Secret Manager (gcloud CLI)
      last_pass                  LastPass (lpass CLI)
      passbolt                   Passbolt (passbolt CLI)
    """)
  end

  def fetch_doppler(args) do
    project = Enum.at(args, 0, "")
    config_name = Enum.at(args, 1, "")
    cmd = "doppler secrets download --no-file --format env -p #{project} -c #{config_name}"

    shell_cmd(cmd, &IO.puts/1, "Doppler fetch failed")
  end

  def fetch_1password([vault, item, field | _]) do
    shell_cmd(
      "op read op://#{vault}/#{item}/#{field}",
      &trimmed_write/1,
      "1Password fetch failed"
    )
  end

  def fetch_1password(_args) do
    say("Usage: mix xamal.secrets.fetch 1password <vault> <item> <field>", :red)
  end

  def fetch_aws_sm(args) do
    {opts, secrets, _} = OptionParser.parse(args, switches: [from: :string, profile: :string])
    prefix = Keyword.get(opts, :from, "")
    profile = Keyword.get(opts, :profile)

    secret_ids = Enum.map(secrets, fn s -> if prefix != "", do: "#{prefix}/#{s}", else: s end)

    if secret_ids == [] do
      say(
        "Usage: mix xamal.secrets.fetch aws_secrets_manager [--from PREFIX] [--profile PROFILE] SECRET...",
        :red
      )
    else
      aws_secrets(secret_ids, profile)
    end
  end

  def fetch_bitwarden(args) do
    {opts, secrets, _} = OptionParser.parse(args, switches: [account: :string])

    case Keyword.get(opts, :account) do
      nil ->
        say("Usage: mix xamal.secrets.fetch bitwarden --account EMAIL ITEM [ITEM/FIELD]...", :red)

      account ->
        with :ok <- bitwarden_login(account), {:ok, session} <- bitwarden_unlock() do
          fetch_bitwarden_secrets(secrets, session)
        end
    end
  end

  def fetch_bitwarden_sm(args) do
    {opts, secrets, _} = OptionParser.parse(args, switches: [from: :string])
    project = Keyword.get(opts, :from)

    if secrets == [] and project == nil do
      say(
        "Usage: mix xamal.secrets.fetch bitwarden_secrets_manager [--from PROJECT] SECRET_UUID...",
        :red
      )
    else
      Enum.each(secrets, &bitwarden_sm_secret/1)
    end
  end

  def fetch_gcp_sm(args) do
    {opts, secrets, _} = OptionParser.parse(args, switches: [account: :string, from: :string])

    if secrets == [] do
      say(
        "Usage: mix xamal.secrets.fetch gcp_secret_manager [--account USER] [--from PROJECT] SECRET...",
        :red
      )
    else
      Enum.each(secrets, &fetch_gcp_secret(&1, opts))
    end
  end

  def fetch_lastpass(args) do
    {opts, secrets, _} = OptionParser.parse(args, switches: [account: :string])

    case Keyword.get(opts, :account) do
      nil ->
        say("Usage: mix xamal.secrets.fetch last_pass --account EMAIL SECRET...", :red)

      account ->
        with :ok <- lastpass_login(account) do
          Enum.each(secrets, &lastpass_secret/1)
        end
    end
  end

  def fetch_passbolt(args) do
    {opts, secrets, _} = OptionParser.parse(args, switches: [from: :string])
    folder = Keyword.get(opts, :from)

    if secrets == [] do
      say("Usage: mix xamal.secrets.fetch passbolt [--from FOLDER] SECRET...", :red)
    else
      Enum.each(secrets, &passbolt_secret(&1, folder))
    end
  end

  defp supported_adapters do
    @adapters |> Map.keys() |> Enum.sort() |> Enum.join(", ")
  end

  defp shell_cmd(command, success, error_prefix) do
    case System.cmd("sh", ["-c", command], stderr_to_stdout: true) do
      {output, 0} -> success.(output)
      {error, _} -> say("#{error_prefix}: #{error}", :red)
    end
  end

  defp command(program, args, success, error_prefix) do
    case System.cmd(program, args, stderr_to_stdout: true) do
      {output, 0} -> success.(output)
      {error, _} -> say("#{error_prefix}: #{error}", :red)
    end
  end

  defp trimmed_write(output), do: IO.write(String.trim(output))

  defp aws_secrets(secret_ids, profile) do
    id_args = Enum.flat_map(secret_ids, fn id -> ["--secret-id-list", id] end)
    profile_args = if profile, do: ["--profile", profile], else: []

    command(
      "aws",
      ["secretsmanager", "batch-get-secret-value"] ++ id_args ++ profile_args,
      &IO.puts/1,
      "AWS Secrets Manager fetch failed"
    )
  end

  defp bitwarden_login(account) do
    case System.cmd("bw", ["login", "--check"], stderr_to_stdout: true) do
      {_, 0} -> bitwarden_login_result(:ok)
      _ -> command_status("bw", ["login", account, "--raw"], "Bitwarden login failed")
    end
  end

  defp bitwarden_login_result(result), do: result

  defp bitwarden_unlock do
    case System.cmd("bw", ["unlock", "--raw"], stderr_to_stdout: true) do
      {session, 0} -> {:ok, String.trim(session)}
      {error, _} -> say_error("Bitwarden unlock failed", error)
    end
  end

  defp fetch_bitwarden_secrets(secrets, session) do
    System.cmd("bw", ["sync", "--session", session], stderr_to_stdout: true)

    Enum.each(secrets, fn secret ->
      shell_cmd(
        "bw get item '#{secret}' --session '#{session}'",
        &IO.puts/1,
        "Failed to fetch '#{secret}'"
      )
    end)
  end

  defp bitwarden_sm_secret(secret) do
    command("bws", ["secret", "get", secret], &IO.puts/1, "Failed to fetch '#{secret}'")
  end

  defp fetch_gcp_secret(secret, opts) do
    {project, name, version} = gcp_secret_parts(secret, Keyword.get(opts, :from))
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

  defp gcp_secret_parts(secret, default_project) do
    case String.split(secret, "/") do
      [project, name, version] -> {project, name, version}
      [project, name] -> {project, name, "latest"}
      [name] -> {default_project, name, "latest"}
    end
  end

  defp lastpass_login(account) do
    case System.cmd("lpass", ["status", "--quiet"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      _ -> command_status("lpass", ["login", account], "LastPass login failed")
    end
  end

  defp lastpass_secret(secret) do
    command("lpass", ["show", "--json", secret], &IO.puts/1, "Failed to fetch '#{secret}'")
  end

  defp passbolt_secret(secret, folder) do
    filter_args = if folder, do: ["--filter", "folder=#{folder}"], else: []
    cmd_args = ["get", "resource", "--filter", "name=#{secret}"] ++ filter_args

    command("passbolt", cmd_args, &IO.puts/1, "Failed to fetch '#{secret}'")
  end

  defp command_status(program, args, error_prefix) do
    case System.cmd(program, args, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, _} -> say_error(error_prefix, error)
    end
  end

  defp say_error(prefix, error) do
    say("#{prefix}: #{error}", :red)
    :error
  end
end
