defmodule Mix.Tasks.Xamal.App.Exec do
  @moduledoc "Runs a command in the release context."
  @shortdoc "Runs command in release"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.App.exec/2)
  end
end
