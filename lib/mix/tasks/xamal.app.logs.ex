defmodule Mix.Tasks.Xamal.App.Logs do
  @moduledoc "Tails or prints application logs."
  @shortdoc "Shows app logs"
  use Mix.Task

  @impl true
  def run(args), do: Xamal.CLI.main(["app", "logs" | args])
end
