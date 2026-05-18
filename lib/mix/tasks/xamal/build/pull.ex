defmodule Mix.Tasks.Xamal.Build.Pull do
  @moduledoc "Uploads the release tarball to target servers."
  @shortdoc "Uploads release tarball"
  use Xamal.MixTask, run: &Xamal.Build.pull/2
end
