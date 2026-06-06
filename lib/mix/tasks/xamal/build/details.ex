defmodule Mix.Tasks.Xamal.Build.Details do
  @moduledoc "Prints release build configuration."
  @shortdoc "Prints build configuration"
  use Xamal.MixTask, run: {Xamal.BuildTasks, :details}
end
