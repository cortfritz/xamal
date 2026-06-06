defmodule Mix.Tasks.Xamal.Init do
  @moduledoc """
  Generates Xamal configuration, secrets, and sample hooks.
  """

  use Mix.Task

  @shortdoc "Generates Xamal configuration"

  @impl true
  def run(args) do
    {opts, _args, _invalid} = OptionParser.parse(args, strict: [yes: :boolean, dry_run: :boolean])

    Xamal.Init.run(
      yes: Keyword.get(opts, :yes, true),
      dry_run: Keyword.get(opts, :dry_run, false)
    )
  end
end
