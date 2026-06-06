defmodule Mix.Tasks.Xamal.Redeploy do
  @moduledoc "Deploys without bootstrapping servers."
  @shortdoc "Deploys without bootstrapping"
  use Xamal.MixTask, run: {Xamal.Deployment, :redeploy}
end
