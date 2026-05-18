defmodule Xamal.Remove do
  @moduledoc """
  Removes remote application and Caddy resources.
  """

  import Xamal.Shell

  alias Xamal.App
  alias Xamal.Commander
  alias Xamal.Commands.Server, as: ServerCommand
  alias Xamal.Commands.Systemd

  def run(_args, opts) do
    confirming("This will remove all releases and Caddy config. Are you sure?", opts, fn ->
      config = Commander.config()

      with_lock(fn ->
        record_audit("Remove started")
        stop_app(opts)
        remove_systemd(config)
        remove_service_directory(config)
        record_audit("Remove completed")
        say("Removed!", :green)
      end)
    end)
  end

  defp stop_app(opts) do
    say("Stopping app...", :magenta)
    App.run("stop", [], opts)
  end

  defp remove_systemd(config) do
    say("Removing systemd units...", :magenta)
    on_hosts(Systemd.disable_all(config))
    on_hosts(Systemd.remove_unit(config))
  end

  defp remove_service_directory(config) do
    say("Removing service directory...", :magenta)
    on_hosts(ServerCommand.remove_service_directory(config))
  end
end
