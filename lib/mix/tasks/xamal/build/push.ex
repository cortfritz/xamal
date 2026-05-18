defmodule Mix.Tasks.Xamal.Build.Push do
  @moduledoc "Builds the release tarball locally."
  @shortdoc "Builds release tarball"
  use Xamal.MixTask, run: &Xamal.BuildTasks.push/3
end
