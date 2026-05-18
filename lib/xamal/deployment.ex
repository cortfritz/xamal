defmodule Xamal.Deployment do
  @moduledoc """
  High-level deployment orchestration.
  """

  import Xamal.DeployLock
  import Xamal.Hooks
  import Xamal.Output
  import Xamal.Remote
  import Xamal.TaskHelpers

  alias Xamal.{AppTasks, BuildTasks, Commander, Context, Prune, ServerTasks}
  alias Xamal.Commands.App, as: AppCommand

  def setup(opts, context \\ Commander.context()) do
    ensure_clean_git!(opts)

    print_runtime(fn ->
      with_lock(fn ->
        record_audit("Setup started", %{}, context)

        say("Bootstrapping servers...", :magenta)
        ServerTasks.bootstrap([], opts, context)

        do_deploy(opts, context)

        record_audit("Setup completed", %{}, context)
      end)
    end)
  end

  def deploy(opts, context \\ Commander.context()) do
    ensure_clean_git!(opts)

    config = context.config
    record_audit("Deploy started", %{version: config.version}, context)

    runtime = print_runtime(fn -> do_deploy(opts, context) end)

    record_audit("Deploy completed", %{version: config.version}, context)
    run_hook("post-deploy", [skip_hooks: Keyword.get(opts, :skip_hooks, false)], context)
    runtime
  end

  def redeploy(opts, context \\ Commander.context()) do
    ensure_clean_git!(opts)

    config = context.config
    record_audit("Redeploy started", %{version: config.version}, context)

    runtime =
      print_runtime(fn ->
        distribute_release(opts, context)

        with_lock(fn ->
          run_hook("pre-deploy", [skip_hooks: Keyword.get(opts, :skip_hooks, false)], context)

          say("Booting app...", :magenta)
          AppTasks.boot([], opts, context)
        end)
      end)

    record_audit("Redeploy completed", %{version: config.version}, context)
    run_hook("post-deploy", [skip_hooks: Keyword.get(opts, :skip_hooks, false)], context)
    runtime
  end

  def deploy_release(opts, context \\ Commander.context()), do: do_deploy(opts, context)

  def rollback(args, opts, context \\ Commander.context())

  def rollback([version | _], opts, context) do
    record_audit("Rollback started", %{version: version}, context)

    print_runtime(fn ->
      with_lock(fn -> run_rollback(version, opts, context) end)
    end)

    record_audit("Rollback completed", %{version: version}, context)
  end

  def rollback([], opts, context) do
    case previous_version(context.config) do
      nil ->
        IO.puts(:stderr, "No previous version found to roll back to.")
        IO.puts(:stderr, "Usage: mix xamal.rollback [VERSION]")

        Mix.raise(
          "No previous version found to roll back to. Usage: mix xamal.rollback [VERSION]"
        )

      previous ->
        say("Auto-detected previous version: #{previous}", :magenta)
        rollback([previous], opts, context)
    end
  end

  defp do_deploy(opts, context) do
    distribute_release(opts, context)

    with_lock(fn ->
      run_hook("pre-deploy", [skip_hooks: Keyword.get(opts, :skip_hooks, false)], context)

      say("Booting app on servers...", :magenta)
      AppTasks.boot([], opts, context)

      say("Pruning old releases...", :magenta)
      Prune.prune([], opts, context)
    end)
  end

  defp run_rollback(version, opts, context) do
    config = context.config
    say("Rolling back to version #{version}...", :magenta)
    run_hook("pre-deploy", [skip_hooks: Keyword.get(opts, :skip_hooks, false)], context)
    Enum.each(Context.roles(context), &rollback_role(config, &1, version))
    run_hook("post-deploy", [skip_hooks: Keyword.get(opts, :skip_hooks, false)], context)
  end

  defp rollback_role(config, role, version) do
    Enum.each(role.hosts, fn host ->
      say("  Rolling back #{host} (#{role.name})...", :magenta)
      new_port = Xamal.BlueGreen.swap(host, config, version)
      say("  Rolled back #{host} to #{version} (port #{new_port})", :green)
    end)
  end

  defp previous_version(config) do
    releases = releases(config)
    current = current_version(config)

    case Enum.drop_while(releases, &(&1 != current)) do
      [_current, previous | _] -> previous
      _ -> nil
    end
  end

  defp releases(config) do
    case on_primary(AppCommand.list_releases(config)) do
      {:ok, output} -> output |> String.trim() |> String.split("\n", trim: true)
      {:error, _} -> []
    end
  end

  defp current_version(config) do
    case on_primary(AppCommand.current_version(config)) do
      {:ok, output} -> String.trim(output)
      {:error, _} -> nil
    end
  end

  defp distribute_release(opts, context) do
    if Keyword.get(opts, :skip_push, false) do
      say("Distributing release to servers...", :magenta)
      BuildTasks.pull([], opts, context)
    else
      say("Building and distributing release...", :magenta)
      BuildTasks.deliver([], opts, context)
    end
  end
end
