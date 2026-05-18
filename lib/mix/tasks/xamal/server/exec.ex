defmodule Mix.Tasks.Xamal.Server.Exec do
  @moduledoc "Runs a shell command on target servers."
  @shortdoc "Runs command on servers"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.Server.exec/2)
  end
end
