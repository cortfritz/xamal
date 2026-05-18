defmodule Mix.Tasks.Xamal.Server.Bootstrap do
  @moduledoc "Bootstraps target servers."
  @shortdoc "Bootstraps servers"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.Server.bootstrap/2)
  end
end
