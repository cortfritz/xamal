defmodule Mix.Tasks.Xamal.App.Stop do
  @moduledoc "Stops application services."
  @shortdoc "Stops app"
  use Xamal.MixTask, run: &Xamal.App.stop/2
end
