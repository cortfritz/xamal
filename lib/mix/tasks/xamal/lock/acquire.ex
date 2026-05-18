defmodule Mix.Tasks.Xamal.Lock.Acquire do
  @moduledoc "Manually acquires the deploy lock."
  @shortdoc "Acquires deploy lock"
  use Xamal.MixTask, run: &Xamal.LockTasks.acquire/3
end
