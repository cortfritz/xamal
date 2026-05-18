defmodule Mix.Tasks.Xamal.Redeploy do
  @moduledoc "Deploys without bootstrapping servers."
  @shortdoc "Deploys without bootstrapping"
  use Xamal.MixTask, run: fn _args, opts -> Xamal.Deployment.redeploy(opts) end
end
