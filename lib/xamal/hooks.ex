defmodule Xamal.Hooks do
  @moduledoc false

  import Xamal.Output

  alias Xamal.Commands.Hook
  alias Xamal.LocalIdentity

  def run_hook(hook_name, opts, context) do
    config = context.config

    if run_hook?(config, hook_name, opts) do
      hook_name
      |> hook_command(config, opts, context)
      |> run_hook_command(hook_name)
    end
  end

  defp run_hook?(config, hook_name, opts) do
    !Keyword.get(opts, :skip_hooks, false) && config && Hook.hook_exists?(config, hook_name)
  end

  defp hook_command(hook_name, config, opts, context) do
    say("Running hook #{hook_name}...", :magenta)
    hook_cmd = Hook.run(config, hook_name)
    hook_env = Hook.env(config, Map.new(Keyword.get(opts, :details, [])), hook_attrs(context))
    env_pairs = Enum.map(hook_env, fn {key, value} -> {to_string(key), to_string(value)} end)
    {Enum.join(hook_cmd, " "), env_pairs}
  end

  defp hook_attrs(context) do
    %{
      performer: LocalIdentity.performer(),
      recorded_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      lock_status: lock_status(context)
    }
  end

  defp lock_status(%{holding_lock: true}), do: "true"
  defp lock_status(_context), do: "false"

  defp run_hook_command({command, env_pairs}, hook_name) do
    case System.cmd("sh", ["-c", command], env: env_pairs, stderr_to_stdout: true) do
      {output, 0} ->
        if output != "", do: IO.puts(output)
        :ok

      {output, code} ->
        say("Hook '#{hook_name}' failed (exit #{code}):", :red)
        IO.puts(output)
        raise "Hook `#{hook_name}` failed"
    end
  end
end
