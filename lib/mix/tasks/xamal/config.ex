defmodule Mix.Tasks.Xamal.Config do
  @moduledoc "Prints the resolved Xamal configuration."
  @shortdoc "Prints resolved configuration"
  use Xamal.MixTask, run: fn _args, _opts -> Xamal.ConfigPrinter.print() end
end
