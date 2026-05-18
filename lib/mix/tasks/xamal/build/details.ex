defmodule Mix.Tasks.Xamal.Build.Details do
  @moduledoc "Prints release build configuration."
  @shortdoc "Prints build configuration"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.Build.details/2)
  end
end
