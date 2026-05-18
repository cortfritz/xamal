defmodule Mix.Tasks.Xamal do
  @moduledoc """
  Runs Xamal commands from Mix.
  """

  use Mix.Task

  @shortdoc "Runs Xamal"

  @impl true
  def run(args) do
    Xamal.CLI.main(args)
  end
end
