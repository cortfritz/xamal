defmodule Mix.Tasks.Xamal.Deploy do
  @moduledoc "Builds, distributes, and boots the release."
  @shortdoc "Deploys the release"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, fn _args, opts -> Xamal.Deployment.deploy(opts) end)
  end
end
