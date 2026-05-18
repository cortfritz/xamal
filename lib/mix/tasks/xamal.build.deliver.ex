defmodule Mix.Tasks.Xamal.Build.Deliver do
  @moduledoc "Builds and uploads the release tarball."
  @shortdoc "Builds and uploads release"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.Build.deliver/2)
  end
end
