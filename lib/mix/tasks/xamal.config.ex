defmodule Mix.Tasks.Xamal.Config do
  @moduledoc "Prints the resolved Xamal configuration."
  @shortdoc "Prints resolved configuration"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, fn _args, _opts -> Xamal.ConfigPrinter.print() end)
  end
end
