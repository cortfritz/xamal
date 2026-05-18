defmodule Mix.Tasks.Xamal.Rollback do
  @moduledoc "Rolls back to a previous release version."
  @shortdoc "Rolls back a release"
  use Xamal.MixTask, run: &Xamal.Deployment.rollback/3
end
