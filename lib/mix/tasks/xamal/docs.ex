defmodule Mix.Tasks.Xamal.Docs do
  @moduledoc "Prints Xamal configuration documentation."
  @shortdoc "Prints configuration docs"
  use Mix.Task

  @impl true
  def run(args), do: Xamal.Docs.run(args)
end
