defmodule Mix.Tasks.Xamal.Audit do
  @moduledoc "Prints the remote deployment audit log."
  @shortdoc "Prints audit log"
  use Xamal.MixTask, run: {Xamal.Audit, :print}
end
