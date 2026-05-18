defmodule Xamal.Shell do
  @moduledoc false

  defdelegate say(message, color \\ :default), to: Xamal.Output
  defdelegate puts_by_host(host, output, opts \\ []), to: Xamal.Output

  defdelegate ensure_clean_git!(opts), to: Xamal.TaskHelpers
  defdelegate print_runtime(fun), to: Xamal.TaskHelpers
  defdelegate confirming(question, opts, fun), to: Xamal.TaskHelpers

  defdelegate run_hook(hook_name, opts \\ []), to: Xamal.Hooks

  defdelegate on_primary(command_parts), to: Xamal.Remote
  defdelegate on_hosts(command_parts), to: Xamal.Remote
  defdelegate record_audit(message, details \\ %{}), to: Xamal.Remote
  defdelegate read_active_port(host, config), to: Xamal.Remote
  defdelegate ssh_exec(host, cmd, config), to: Xamal.Remote

  defdelegate with_lock(fun), to: Xamal.DeployLock
  defdelegate blue_green_swap(host, config, version, opts \\ []), to: Xamal.BlueGreen, as: :swap

  defdelegate parse_log_opts(args), to: Xamal.Logs
  defdelegate dispatch_logs(log_opts, build_cmd, config, opts \\ []), to: Xamal.Logs
end
