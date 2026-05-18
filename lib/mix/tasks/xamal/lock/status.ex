defmodule Mix.Tasks.Xamal.Lock.Status do
  @moduledoc "Prints deploy lock status."
  @shortdoc "Shows lock status"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.Lock.status/2)
  end
end
