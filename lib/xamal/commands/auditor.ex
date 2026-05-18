defmodule Xamal.Commands.Auditor do
  @moduledoc """
  Audit log commands. Appends timestamped entries to the audit log.
  """

  import Xamal.Commands.Base

  @doc """
  Record an audit log entry.
  """
  def record(config, line, timestamp, details \\ %{}) do
    tags = format_tags(config, details, timestamp)
    escaped = Xamal.Utils.shell_escape("#{tags} #{line}")

    combine([
      make_directory(Xamal.Configuration.run_directory()),
      append([
        ["echo", escaped],
        [audit_log_file(config)]
      ])
    ])
  end

  @doc """
  Show the last 50 lines of the audit log.
  """
  def reveal(config) do
    ["tail", "-n", "50", audit_log_file(config)]
  end

  defp audit_log_file(config) do
    Xamal.Configuration.audit_log_path(config)
  end

  defp format_tags(config, details, timestamp) do
    service = Xamal.Configuration.service(config)

    base = "[#{timestamp}] [#{service}]"

    extra =
      details
      |> Enum.map(fn {key, value} -> ["[", to_string(key), ": ", to_string(value), "]"] end)
      |> Enum.intersperse(" ")
      |> IO.iodata_to_binary()

    if extra == "", do: base, else: "#{base} #{extra}"
  end
end
