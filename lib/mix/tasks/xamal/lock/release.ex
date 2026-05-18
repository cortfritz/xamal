defmodule Mix.Tasks.Xamal.Lock.Release do
  @moduledoc "Releases the deploy lock."
  @shortdoc "Releases deploy lock"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.Lock.release/2)
  end
end
