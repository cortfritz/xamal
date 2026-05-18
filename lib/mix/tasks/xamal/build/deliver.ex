defmodule Mix.Tasks.Xamal.Build.Deliver do
  @moduledoc "Builds and uploads the release tarball."
  @shortdoc "Builds and uploads release"
  use Xamal.MixTask, run: {Xamal.BuildTasks, :deliver}
end
