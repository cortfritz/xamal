defmodule Mix.Tasks.Xamal.Build.Push do
  @moduledoc "Builds the release tarball locally."
  @shortdoc "Builds release tarball"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.Build.push/2)
  end
end
