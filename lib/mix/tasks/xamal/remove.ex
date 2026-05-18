defmodule Mix.Tasks.Xamal.Remove do
  @moduledoc "Removes remote release and proxy resources."
  @shortdoc "Removes remote resources"
  use Xamal.MixTask, run: {Xamal.Remove, :run}
end
