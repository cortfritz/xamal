defmodule Mix.Tasks.Xamal.Build.Pull do
  @moduledoc "Uploads the release tarball to target servers."
  @shortdoc "Uploads release tarball"
  use Xamal.MixTask, run: &Xamal.BuildTasks.pull/2
end
