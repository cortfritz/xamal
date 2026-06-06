defmodule Mix.Tasks.Xamal.Server.Bootstrap do
  @moduledoc "Bootstraps target servers."
  @shortdoc "Bootstraps servers"
  use Xamal.MixTask, run: {Xamal.ServerTasks, :bootstrap}
end
