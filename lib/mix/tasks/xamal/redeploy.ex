defmodule Mix.Tasks.Xamal.Redeploy do
  @moduledoc "Deploys without bootstrapping servers."
  @shortdoc "Deploys without bootstrapping"
  use Xamal.MixTask, run: fn _args, opts, context -> Xamal.Deployment.redeploy(opts, context) end
end
