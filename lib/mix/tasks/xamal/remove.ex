defmodule Mix.Tasks.Xamal.Remove do
  @moduledoc "Removes remote release and proxy resources."
  @shortdoc "Removes remote resources"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.Operations.remove/2)
  end
end
