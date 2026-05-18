defmodule Mix.Tasks.Xamal.Versions do
  @moduledoc "Lists release versions on servers."
  @shortdoc "Lists release versions"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.Operations.versions/2)
  end
end
