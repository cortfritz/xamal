defmodule Mix.Tasks.Xamal.App.Boot do
  @moduledoc "Boots the application on servers."
  @shortdoc "Boots the app"
  use Mix.Task

  @impl true
  def run(args) do
    Xamal.MixTask.run(args, &Xamal.App.boot/2)
  end
end
