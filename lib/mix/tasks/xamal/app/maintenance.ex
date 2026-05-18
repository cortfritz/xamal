defmodule Mix.Tasks.Xamal.App.Maintenance do
  @moduledoc "Enables maintenance mode."
  @shortdoc "Enables maintenance mode"
  use Xamal.MixTask, run: &Xamal.AppTasks.maintenance/3
end
