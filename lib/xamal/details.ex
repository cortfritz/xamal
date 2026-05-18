defmodule Xamal.Details do
  @moduledoc """
  Prints application and proxy status for selected hosts.
  """

  import Xamal.Shell

  alias Xamal.Commander
  alias Xamal.Commands.App, as: AppCommand
  alias Xamal.SSH

  def print(_args, _opts) do
    config = Commander.config()

    Enum.each(Commander.hosts(), fn host ->
      say("Host: #{host}", :magenta)
      print_host_details(host, config)
      IO.puts("")
    end)
  end

  defp print_host_details(host, config) do
    active_port = read_active_port(host, config)

    case SSH.execute_command(host, AppCommand.details(config, active_port),
           ssh_config: config.ssh
         ) do
      {:ok, output} -> IO.puts(output)
      {:error, reason} -> say("  Error: #{inspect(reason)}", :red)
    end
  end
end
