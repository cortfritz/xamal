defmodule Mix.Tasks.Xamal.App.Live do
  @moduledoc "Disables maintenance mode."
  @shortdoc "Disables maintenance mode"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.App.live/2)
  end
end
