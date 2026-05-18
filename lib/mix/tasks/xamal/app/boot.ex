defmodule Mix.Tasks.Xamal.App.Boot do
  @moduledoc "Boots the application on servers."
  @shortdoc "Boots the app"
  use Xamal.MixTask, run: {Xamal.AppTasks, :boot}
end
