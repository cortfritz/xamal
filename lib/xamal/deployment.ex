defmodule Xamal.Deployment do
  @moduledoc """
  High-level deployment orchestration.
  """

  import Xamal.DeployLock
  import Xamal.Hooks
  import Xamal.Output
  import Xamal.Remote
  import Xamal.TaskHelpers

  alias Xamal.{App, Build, Commander, Prune, Server}
  alias Xamal.Commands.App, as: AppCommand

  def setup(opts) do
    ensure_clean_git!(opts)

    print_runtime(fn ->
      with_lock(fn ->
        record_audit("Setup started")

        say("Bootstrapping servers...", :magenta)
        Server.run("bootstrap", [], opts)

        do_deploy(opts)

        record_audit("Setup completed")
      end)
    end)
  end

  def deploy(opts) do
    ensure_clean_git!(opts)

    config = Commander.config()
    record_audit("Deploy started", %{version: config.version})

    runtime = print_runtime(fn -> do_deploy(opts) end)

    record_audit("Deploy completed", %{version: config.version})
    run_hook("post-deploy", skip_hooks: Keyword.get(opts, :skip_hooks, false))
    runtime
  end

  def redeploy(opts) do
    ensure_clean_git!(opts)

    config = Commander.config()
    record_audit("Redeploy started", %{version: config.version})

    runtime =
      print_runtime(fn ->
        distribute_release(opts)

        with_lock(fn ->
          run_hook("pre-deploy", skip_hooks: Keyword.get(opts, :skip_hooks, false))

          say("Booting app...", :magenta)
          App.run("boot", [], opts)
        end)
      end)

    record_audit("Redeploy completed", %{version: config.version})
    run_hook("post-deploy", skip_hooks: Keyword.get(opts, :skip_hooks, false))
    runtime
  end

  def deploy_release(opts), do: do_deploy(opts)

  def rollback([version | _], opts) do
    record_audit("Rollback started", %{version: version})

    print_runtime(fn ->
      with_lock(fn -> run_rollback(version, opts) end)
    end)

    record_audit("Rollback completed", %{version: version})
  end

  def rollback([], opts) do
    case previous_version(Commander.config()) do
      nil ->
        IO.puts(:stderr, "No previous version found to roll back to.")
        IO.puts(:stderr, "Usage: mix xamal.rollback [VERSION]")
        System.halt(1)

      previous ->
        say("Auto-detected previous version: #{previous}", :magenta)
        rollback([previous], opts)
    end
  end

  defp do_deploy(opts) do
    distribute_release(opts)

    with_lock(fn ->
      run_hook("pre-deploy", skip_hooks: Keyword.get(opts, :skip_hooks, false))

      say("Booting app on servers...", :magenta)
      App.run("boot", [], opts)

      say("Pruning old releases...", :magenta)
      Prune.prune([], opts)
    end)
  end

  defp run_rollback(version, opts) do
    config = Commander.config()
    say("Rolling back to version #{version}...", :magenta)
    run_hook("pre-deploy", skip_hooks: Keyword.get(opts, :skip_hooks, false))
    Enum.each(Commander.roles(), &rollback_role(config, &1, version))
    run_hook("post-deploy", skip_hooks: Keyword.get(opts, :skip_hooks, false))
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

  defp distribute_release(opts) do
    if Keyword.get(opts, :skip_push, false) do
      say("Distributing release to servers...", :magenta)
      Build.run("pull", [], opts)
    else
      say("Building and distributing release...", :magenta)
      Build.run("deliver", [], opts)
    end
  end
end
