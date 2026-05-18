defmodule Mix.Tasks.Xamal.App.Maintenance do
  @moduledoc "Enables maintenance mode."
  @shortdoc "Enables maintenance mode"
  use Xamal.MixTask, run: &Xamal.App.maintenance/2
end
