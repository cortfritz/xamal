defmodule Mix.Tasks.Xamal.Server.Exec do
  @moduledoc "Runs a shell command on target servers."
  @shortdoc "Runs command on servers"
  use Xamal.MixTask, run: &Xamal.ServerTasks.exec/2
end
