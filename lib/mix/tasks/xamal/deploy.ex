defmodule Mix.Tasks.Xamal.Deploy do
  @moduledoc "Builds, distributes, and boots the release."
  @shortdoc "Deploys the release"
  use Xamal.MixTask, run: fn _args, opts, context -> Xamal.Deployment.deploy(opts, context) end
end
