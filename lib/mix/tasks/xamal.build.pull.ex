defmodule Mix.Tasks.Xamal.Build.Pull do
  @moduledoc "Uploads the release tarball to target servers."
  @shortdoc "Uploads release tarball"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.Build.pull/2)
  end
end
