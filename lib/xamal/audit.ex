defmodule Xamal.Audit do
  @moduledoc """
  Prints the remote deployment audit log for selected hosts.
  """

  import Xamal.Output

  alias Xamal.Commander
  alias Xamal.Commands.Auditor
  alias Xamal.SSH

  def print(_args, _opts) do
    config = Commander.config()

    Enum.each(Commander.hosts(), fn host ->
      case SSH.execute_command(host, Auditor.reveal(config), ssh_config: config.ssh) do
        {:ok, output} -> puts_by_host(host, output)
        {:error, _} -> puts_by_host(host, "(no audit log)")
      end
    end)
  end
end
