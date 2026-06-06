defmodule Xamal.Commands.Prune do
  @moduledoc """
  Commands for pruning old releases.
  """

  import Xamal.Commands.Base

  alias Xamal.Configuration

  @doc """
  Remove old release directories, keeping the N most recent.
  Always protects the current (active) version from pruning.
  """
  def releases(config) do
    keep = Configuration.retain_releases(config)
    releases_dir = Configuration.releases_directory(config)
    current_link = Configuration.current_link(config)

    pipe([
      ["ls", "-1t", releases_dir],
      ["grep", "-v", "\"$(basename $(readlink -f #{current_link}))\""],
      ["tail", "-n", "+#{keep + 1}"],
      ["xargs", "-I", "{}", "rm", "-rf", "#{releases_dir}/{}"]
    ])
  end
end
