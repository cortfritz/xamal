defmodule Mix.Tasks.Xamal.Secrets.Print do
  @moduledoc "Prints configured secrets with sensitive values redacted."
  @shortdoc "Prints redacted secrets"
  use Xamal.MixTask, run: &Xamal.SecretTasks.print_secrets/3
end
