defmodule Mix.Tasks.Xamal.App.Stop do
  @moduledoc "Stops application services."
  @shortdoc "Stops app"
  use Xamal.MixTask, run: &Xamal.AppTasks.stop/3
end
