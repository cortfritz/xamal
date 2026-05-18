defmodule Mix.Tasks.Xamal.App.Logs do
  @moduledoc "Tails or prints application logs."
  @shortdoc "Shows app logs"
  use Xamal.MixTask, run: &Xamal.AppTasks.logs/3
end
