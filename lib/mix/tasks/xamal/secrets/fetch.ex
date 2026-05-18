defmodule Mix.Tasks.Xamal.Secrets.Fetch do
  @moduledoc "Fetches secrets from an external secret store."
  @shortdoc "Fetches secrets"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.SecretTasks.fetch/2)
  end
end
