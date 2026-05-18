defmodule Mix.Tasks.Xamal.Secrets.Extract do
  @moduledoc "Prints a single configured secret value."
  @shortdoc "Prints secret value"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.SecretCommands.extract/2)
  end
end
