defmodule Mix.Tasks.Xamal.Build.Details do
  @moduledoc "Prints release build configuration."
  @shortdoc "Prints build configuration"
  use Xamal.MixTask, run: &Xamal.Build.details/2
end
