defmodule Mix.Tasks.Xamal.Lock.Acquire do
  @moduledoc "Manually acquires the deploy lock."
  @shortdoc "Acquires deploy lock"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.Lock.acquire/2)
  end
end
