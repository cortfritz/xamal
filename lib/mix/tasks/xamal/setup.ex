defmodule Mix.Tasks.Xamal.Setup do
  @moduledoc "Bootstraps servers and deploys the release."
  @shortdoc "Bootstraps servers and deploys"
  use Xamal.MixTask, run: fn _args, opts, context -> Xamal.Deployment.setup(opts, context) end
end
