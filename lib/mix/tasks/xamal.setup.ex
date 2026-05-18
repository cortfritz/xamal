defmodule Mix.Tasks.Xamal.Setup do
  @moduledoc "Bootstraps servers and deploys the release."
  @shortdoc "Bootstraps servers and deploys"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, fn _args, opts -> Xamal.Deployment.setup(opts) end)
  end
end
