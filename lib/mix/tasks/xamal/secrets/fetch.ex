defmodule Mix.Tasks.Xamal.Secrets.Fetch do
  @moduledoc "Fetches secrets from an external secret store."
  @shortdoc "Fetches secrets"
  use Xamal.MixTask, run: &Xamal.SecretTasks.fetch/2
end
