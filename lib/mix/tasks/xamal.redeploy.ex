defmodule Mix.Tasks.Xamal.Redeploy do
  @moduledoc "Deploys without bootstrapping servers."
  @shortdoc "Deploys without bootstrapping"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, fn _args, opts -> Xamal.Deployment.redeploy(opts) end)
  end
end
