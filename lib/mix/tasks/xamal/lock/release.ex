defmodule Mix.Tasks.Xamal.Lock.Release do
  @moduledoc "Releases the deploy lock."
  @shortdoc "Releases deploy lock"
  use Xamal.MixTask, run: &Xamal.Lock.release/2
end
