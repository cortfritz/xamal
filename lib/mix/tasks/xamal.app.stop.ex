defmodule Mix.Tasks.Xamal.App.Stop do
  @moduledoc "Stops application services."
  @shortdoc "Stops app"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.App.stop/2)
  end
end
