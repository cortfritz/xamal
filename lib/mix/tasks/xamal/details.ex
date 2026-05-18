defmodule Mix.Tasks.Xamal.Details do
  @moduledoc "Prints application and proxy status."
  @shortdoc "Prints app details"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.Details.print/2)
  end
end
