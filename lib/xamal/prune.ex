defmodule Xamal.Prune do
  @moduledoc """
  Prunes old releases on selected hosts.
  """

  import Xamal.Shell

  alias Xamal.{Commander, SSH}
  alias Xamal.Commands.Prune, as: PruneCommand
  alias Xamal.Configuration

  def prune(_args, _opts) do
    config = Commander.config()
    hosts = Commander.hosts()
    keep = Configuration.retain_releases(config)

    say("Pruning old releases (keeping #{keep})...", :magenta)

    Enum.each(hosts, fn host ->
      cmd = PruneCommand.releases(config)

      case SSH.execute_command(host, cmd, ssh_config: config.ssh) do
        {:ok, _} -> say("  Pruned on #{host}", :green)
        {:error, _} -> say("  Nothing to prune on #{host}", :yellow)
      end
    end)
  end
end
