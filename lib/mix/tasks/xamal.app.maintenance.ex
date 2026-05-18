defmodule Mix.Tasks.Xamal.App.Maintenance do
  @moduledoc "Enables maintenance mode."
  @shortdoc "Enables maintenance mode"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.App.maintenance/2)
  end
end
