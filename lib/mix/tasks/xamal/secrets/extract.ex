defmodule Mix.Tasks.Xamal.Secrets.Extract do
  @moduledoc "Prints a single configured secret value."
  @shortdoc "Prints secret value"
  use Xamal.MixTask, run: &Xamal.SecretTasks.extract/2
end
