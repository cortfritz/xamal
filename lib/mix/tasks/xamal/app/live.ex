defmodule Mix.Tasks.Xamal.App.Live do
  @moduledoc "Disables maintenance mode."
  @shortdoc "Disables maintenance mode"
  use Xamal.MixTask, run: &Xamal.AppTasks.live/2
end
