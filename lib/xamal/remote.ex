defmodule Xamal.Remote do
  @moduledoc false

  alias Xamal.{Commander, SSH}
  alias Xamal.Commands.{Auditor, Caddy}

  def on_primary(command_parts), do: on_primary(command_parts, Commander.context())

  def on_primary(command_parts, context) do
    config = context.config
    host = Xamal.Context.primary_host(context)
    SSH.execute_command(host, command_parts, ssh_config: config.ssh)
  end

  def on_hosts(command_parts), do: on_hosts(command_parts, Commander.context())

  def on_hosts(command_parts, context) do
    config = context.config

    context
    |> Xamal.Context.hosts()
    |> SSH.on(fn host -> SSH.execute_command(host, command_parts, ssh_config: config.ssh) end)
  end

  def record_audit(message, details \\ %{}),
    do: record_audit(message, details, Commander.context())

  def record_audit(message, details, context) do
    config = context.config

    if config do
      config
      |> Auditor.record(message, DateTime.utc_now() |> DateTime.to_iso8601(), details)
      |> on_primary(context)
    end
  end

  def read_active_port(host, config) do
    case SSH.execute_command(host, Caddy.read_active_port(config), ssh_config: config.ssh) do
      {:ok, port_str} -> parse_port(port_str)
      {:error, _} -> nil
    end
  end

  def ssh_exec(host, cmd, config) do
    SSH.execute_command(host, cmd, ssh_config: config.ssh)
  end

  defp parse_port(port_str) do
    case Integer.parse(String.trim(port_str)) do
      {port, _} -> port
      :error -> nil
    end
  end
end
