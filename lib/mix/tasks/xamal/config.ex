defmodule Mix.Tasks.Xamal.Config do
  @moduledoc "Prints the resolved Xamal configuration."
  @shortdoc "Prints resolved configuration"
  use Xamal.MixTask, run: {Xamal.ConfigPrinter, :print}
end
