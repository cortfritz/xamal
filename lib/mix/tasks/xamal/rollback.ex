defmodule Mix.Tasks.Xamal.Rollback do
  @moduledoc "Rolls back to a previous release version."
  @shortdoc "Rolls back a release"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.Deployment.rollback/2)
  end
end
