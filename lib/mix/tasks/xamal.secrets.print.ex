defmodule Mix.Tasks.Xamal.Secrets.Print do
  @moduledoc "Prints configured secrets with sensitive values redacted."
  @shortdoc "Prints redacted secrets"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.SecretCommands.print_secrets/2)
  end
end
