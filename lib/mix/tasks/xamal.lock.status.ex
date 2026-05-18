defmodule Mix.Tasks.Xamal.Lock.Status do
  @moduledoc "Prints deploy lock status."
  @shortdoc "Shows lock status"
  use Mix.Task

  @impl true
  def run(args), do: Xamal.CLI.main(["lock", "status" | args])
end
