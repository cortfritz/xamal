defmodule Mix.Tasks.Xamal do
  @moduledoc "Prints Xamal task help."
  @shortdoc "Prints Xamal help"
  use Mix.Task

  @impl true
  def run(_args) do
    Mix.shell().info("""
    Xamal tasks:

      mix xamal.init
      mix xamal.config
      mix xamal.setup
      mix xamal.deploy
      mix xamal.redeploy
      mix xamal.rollback [VERSION]
      mix xamal.server.bootstrap
      mix xamal.app.boot
      mix xamal.app.logs
      mix xamal.app.exec COMMAND
      mix xamal.app.maintenance
      mix xamal.lock.status
      mix xamal.lock.acquire [-m MESSAGE]
      mix xamal.lock.release
    """)
  end
end
