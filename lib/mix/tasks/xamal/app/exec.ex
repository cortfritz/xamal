defmodule Mix.Tasks.Xamal.App.Exec do
  @moduledoc "Runs a command in the release context."
  @shortdoc "Runs command in release"
  use Xamal.MixTask, run: &Xamal.App.exec/2
end
