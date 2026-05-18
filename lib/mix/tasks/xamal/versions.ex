defmodule Mix.Tasks.Xamal.Versions do
  @moduledoc "Lists release versions on servers."
  @shortdoc "Lists release versions"
  use Xamal.MixTask, run: &Xamal.Versions.list/2
end
