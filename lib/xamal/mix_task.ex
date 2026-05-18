defmodule Xamal.MixTask do
  @moduledoc false

  alias Xamal.{Commander, CommandOptions, Configuration}

  defmacro __using__(opts) do
    callback = Keyword.fetch!(opts, :run)

    quote do
      use Mix.Task

      @impl true
      def run(args) do
        Xamal.MixTask.run(args, unquote(callback))
      end
    end
  end

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
    confirmed: :boolean
  ]

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

  def run(args, callback) when is_function(callback, 2) do
    Application.ensure_all_started(:xamal)

    {opts, rest} = parse_global_options(args)
    opts |> load_config!() |> configure_commander(opts)
    callback.(rest, opts)
  end

  defp parse_global_options(args) do
    {opts, rest, invalid} =
      OptionParser.parse_head(args, strict: @global_switches, aliases: @global_aliases)

    if invalid != [] do
      invalid_options = Enum.map_join(invalid, ", ", fn {flag, _value} -> flag end)
      Mix.raise("Unknown option: #{invalid_options}")
    end

    {opts, rest}
  end

  defp load_config!(opts) do
    config_file = Keyword.get(opts, :config_file, "config/xamal.exs")

    unless File.exists?(config_file) do
      Mix.raise("Configuration file not found: #{config_file}. Run 'mix xamal.init'.")
    end

    Configuration.create_from(
      config_file: config_file,
      destination: Keyword.get(opts, :destination),
      version: Keyword.get(opts, :version)
    )
  end

  defp configure_commander(config, opts) do
    Commander.configure(config)
    CommandOptions.apply_filters_and_verbosity(opts)
    config
  end
end
