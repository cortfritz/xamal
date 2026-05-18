defmodule Xamal.CLI do
  @moduledoc """
  CLI entry point. Parses global options, dispatches to subcommands.

  This is the main_module for the escript.
  """

  @global_switches [
    verbose: :boolean,
    quiet: :boolean,
    version: :string,
    primary: :boolean,
    hosts: :string,
    roles: :string,
    config_file: :string,
    destination: :string,
    skip_hooks: :boolean,
    skip_dirty_check: :boolean,
    confirmed: :boolean,
    help: :boolean
  ]

  alias Xamal.CLI.{Docs, Main, Secrets}
  alias Xamal.{App, Build, CommandOptions, Commander, Configuration, Lock, Prune, Server}

  @global_aliases [
    v: :verbose,
    q: :quiet,
    p: :primary,
    h: :hosts,
    r: :roles,
    c: :config_file,
    d: :destination,
    H: :skip_hooks,
    y: :confirmed
  ]

  @main_commands %{
    "setup" => {Main, :setup},
    "deploy" => {Main, :deploy},
    "redeploy" => {Main, :redeploy},
    "rollback" => {Main, :rollback},
    "details" => {Main, :details},
    "versions" => {Main, :versions},
    "audit" => {Main, :audit},
    "config" => {Main, :config},
    "remove" => {Main, :remove},
    "prune" => {Prune, :prune}
  }

  @subcommands %{
    "app" => App,
    "build" => Build,
    "lock" => Lock,
    "secrets" => Secrets,
    "server" => Server
  }

  def main(argv) do
    Application.ensure_all_started(:xamal)
    Logger.configure(level: :info)

    argv
    |> parse_args()
    |> run_command()
  rescue
    e ->
      IO.puts(:stderr, "Error: #{Exception.message(e)}")
      IO.puts(:stderr, Exception.format(:error, e, __STACKTRACE__))
      System.halt(1)
  catch
    :exit, {:timeout, {GenServer, :call, _}} ->
      IO.puts(
        :stderr,
        "Error: SSH connection timed out. Verify the host is reachable and SSH is running."
      )

      System.halt(1)

    :exit, reason ->
      IO.puts(:stderr, "Error: #{inspect(reason)}")
      System.halt(1)
  end

  defp parse_args(["--version"]), do: {:version, [], []}

  defp parse_args(argv) do
    {head_opts, args, invalid} =
      OptionParser.parse_head(argv, strict: @global_switches, aliases: @global_aliases)

    ensure_valid_options!(invalid)

    {command, rest} = split_command(args)

    {tail_opts, rest, _invalid} =
      OptionParser.parse_head(rest, switches: @global_switches, aliases: @global_aliases)

    {command, rest, Keyword.merge(head_opts, tail_opts)}
  end

  defp ensure_valid_options!([]), do: :ok

  defp ensure_valid_options!(invalid) do
    flags = Enum.map_join(invalid, ", ", fn {flag, _} -> flag end)
    IO.puts(:stderr, "Unknown option: #{flags}")
    System.halt(1)
  end

  defp split_command([]), do: {nil, []}
  defp split_command([command | rest]), do: {command, rest}

  defp run_command({command, args, opts}) do
    if Keyword.get(opts, :help) do
      print_command_help(command)
      System.halt(0)
    else
      run_command(command, args, opts)
    end
  end

  defp print_command_help(nil), do: print_help()

  defp print_command_help(command) do
    dispatch_help(command, ["--help"]) || print_help()
  end

  defp run_command(nil, _args, _opts), do: print_help()
  defp run_command(:version, _args, _opts), do: print_version()
  defp run_command("version", _args, _opts), do: print_version()
  defp run_command("init", args, opts), do: Main.init(args, opts)
  defp run_command("docs", args, _opts), do: Docs.run(args)
  defp run_command(command, args, opts), do: dispatch(command, args, opts)

  defp dispatch(command, args, global_opts) do
    if dispatch_help(command, args) do
      :ok
    else
      dispatch_with_config(command, args, global_opts)
    end
  end

  defp dispatch_help(command, args) when args in [[], ["--help"]] do
    case Map.get(@subcommands, command) do
      nil -> if args == ["--help"], do: print_help()
      module -> module.help()
    end
  end

  defp dispatch_help(_command, _args), do: nil

  defp dispatch_with_config(command, args, global_opts) do
    config = global_opts |> init_config() |> ensure_config!(global_opts)
    ensure_commander(config, global_opts)
    dispatch_configured_command(command, args, global_opts)
  end

  defp dispatch_configured_command(command, args, global_opts) do
    cond do
      handler = Map.get(@main_commands, command) ->
        apply_command(handler, args, global_opts)

      module = Map.get(@subcommands, command) ->
        dispatch_subcommand(module, args, global_opts)

      true ->
        check_alias(command, args, global_opts)
    end
  end

  defp ensure_config!(nil, global_opts) do
    config_file = Keyword.get(global_opts, :config_file, "config/xamal.exs")
    IO.puts(:stderr, "Configuration file not found: #{config_file}")
    IO.puts(:stderr, "Run 'mix xamal.init' to generate a configuration file.")
    System.halt(1)
  end

  defp ensure_config!(config, _global_opts), do: config

  defp apply_command({module, function}, args, global_opts) do
    apply(module, function, [args, global_opts])
  end

  defp dispatch_subcommand(module, args, global_opts) do
    case args do
      [] -> module.help()
      [sub | rest] -> module.run(sub, rest, global_opts)
    end
  end

  defp check_alias(command, args, global_opts) do
    config = Commander.config()
    aliases = if config, do: config.aliases || %{}, else: %{}

    case Map.get(aliases, command) do
      nil ->
        IO.puts(:stderr, "Unknown command: #{command}. Run 'xamal --help' for usage.")
        System.halt(1)

      alias_cmd ->
        # Dispatch directly to avoid re-parsing global options,
        # which would strip subcommand-specific flags like -i
        alias_argv = OptionParser.split(alias_cmd) ++ args

        case alias_argv do
          [cmd | rest] -> dispatch(cmd, rest, global_opts)
          [] -> :ok
        end
    end
  end

  defp init_config(global_opts) do
    # Return cached config if already loaded (avoids double load for alias dispatch)
    case Process.get(:xamal_config) do
      nil ->
        config_file = Keyword.get(global_opts, :config_file, "config/xamal.exs")
        destination = Keyword.get(global_opts, :destination)
        version = Keyword.get(global_opts, :version)

        # For init command, config may not exist yet
        config =
          if File.exists?(config_file) do
            Configuration.create_from(
              config_file: config_file,
              destination: destination,
              version: version
            )
          else
            nil
          end

        Process.put(:xamal_config, config)
        config

      config ->
        config
    end
  end

  defp ensure_commander(config, global_opts) do
    if Commander.configured?() do
      :ok
    else
      configure_commander(config)
      CommandOptions.apply_filters_and_verbosity(global_opts)
    end
  end

  defp configure_commander(nil), do: :ok
  defp configure_commander(config), do: Commander.configure(config)

  defp print_version do
    IO.puts("Xamal #{Xamal.version()}")
  end

  defp print_help do
    IO.puts("""
    Xamal - Deploy Elixir releases to bare metal servers

    Usage: xamal <command> [options]

    Commands:
      setup               Setup servers and deploy
      deploy              Deploy app to servers
      redeploy            Deploy without bootstrapping
      rollback [VERSION]  Rollback to a previous version
      versions            List release versions on servers
      details             Show app and caddy status
      audit               Show audit log
      config              Show merged config
      init                Generate config stubs
      docs [TOPIC]        Show configuration documentation
      version             Show xamal version
      prune               Remove old releases
      remove              Remove everything from servers

    Subcommands:
      app                 Manage application (boot, start, stop, exec, logs)
      build               Build and distribute releases
      lock                Manage deploy lock
      secrets             Manage secrets
      server              Server management (exec, bootstrap, logs)

    Global options:
      -v, --verbose       Detailed logging
      -q, --quiet         Minimal logging
      -p, --primary       Run only on primary host
      -h, --hosts HOSTS   Run on specific hosts (comma-separated)
      -r, --roles ROLES   Run on specific roles (comma-separated)
      -c, --config-file   Path to config file (default: config/xamal.exs)
      -d, --destination   Destination (staging, production, etc.)
      -H, --skip-hooks    Skip hook scripts
      --skip-dirty-check  Allow deploy with uncommitted changes
      -y, --confirmed     Skip confirmation prompts
    """)
  end
end
