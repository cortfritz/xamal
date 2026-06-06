defmodule Xamal.Secrets.Adapters.Helpers do
  @moduledoc false

  import Xamal.Output

  def shell_cmd(command, success, error_prefix) do
    case System.cmd("sh", ["-c", command], stderr_to_stdout: true) do
      {output, 0} -> success.(output)
      {error, _} -> say("#{error_prefix}: #{error}", :red)
    end
  end

  def command(program, args, success, error_prefix) do
    case System.cmd(program, args, stderr_to_stdout: true) do
      {output, 0} -> success.(output)
      {error, _} -> say("#{error_prefix}: #{error}", :red)
    end
  end

  def command_status(program, args, error_prefix) do
    case System.cmd(program, args, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, _} -> say_error(error_prefix, error)
    end
  end

  def trimmed_write(output), do: IO.write(String.trim(output))

  def say_error(prefix, error) do
    say("#{prefix}: #{error}", :red)
    :error
  end
end
