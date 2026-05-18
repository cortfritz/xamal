defmodule Mix.Tasks.Xamal.Details do
  @moduledoc "Prints application and proxy status."
  @shortdoc "Prints app details"
  use Xamal.MixTask, run: &Xamal.Details.print/2
end
