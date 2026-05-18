defmodule Mix.Tasks.Xamal.Audit do
  @moduledoc "Prints the remote deployment audit log."
  @shortdoc "Prints audit log"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.Operations.audit/2)
  end
end
