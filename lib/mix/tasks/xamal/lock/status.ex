defmodule Mix.Tasks.Xamal.Lock.Status do
  @moduledoc "Prints deploy lock status."
  @shortdoc "Shows lock status"
  use Xamal.MixTask, run: &Xamal.Lock.status/2
end
