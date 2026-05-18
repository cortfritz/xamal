defmodule Xamal.IntegrationHelpers do
  @moduledoc false

  @xamal_config """
  import Config

  config :xamal,
    service: "test-app",
    servers: [
      web: ["10.0.0.1", "10.0.0.2"],
      worker: [
        hosts: ["10.0.0.3"],
        cmd: "bin/test_app eval \\\"Worker.start()\\\""
      ]
    ],
    ssh: [
      user: "deploy",
      port: 22,
      connect_timeout: 0
    ],
    caddy: [
      host: "test.example.com",
      app_port: 4000
    ],
    env: [
      clear: [
        PHX_HOST: "test.example.com"
      ],
      secret: ["SECRET_KEY_BASE"]
    ],
    release: [
      name: "test_app",
      mix_env: "prod"
    ],
    health_check: [
      path: "/health",
      interval: 1,
      timeout: 30
    ],
    boot: [
      limit: 2,
      wait: 1
    ],
    retain_releases: 3
  """

  @secrets_file """
  SECRET_KEY_BASE=super_secret_value_123
  """

  def setup_temp_dir do
    dir = Path.join(System.tmp_dir!(), "xamal_e2e_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end

  def setup_config(dir) do
    File.mkdir_p!(Path.join(dir, "config"))
    File.write!(Path.join(dir, "config/xamal.exs"), @xamal_config)
    File.mkdir_p!(Path.join(dir, ".xamal"))
    File.write!(Path.join(dir, ".xamal/secrets"), @secrets_file)
  end

  def setup_git_repo(dir) do
    System.cmd(
      "sh",
      [
        "-c",
        "git init -b master --quiet 2>/dev/null && " <>
          "git config user.email test@test.com && " <>
          "git config user.name Test && " <>
          "git add . && " <>
          "git commit -m init --quiet 2>/dev/null"
      ],
      cd: dir
    )
  end

  def xamal(args, dir) do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        File.cd!(dir, fn -> run_mix_task(args) end)
      end)

    {output, 0}
  rescue
    error in Mix.Error -> {Exception.message(error), 1}
  end

  defp run_mix_task(["config" | args]), do: Mix.Task.rerun("xamal.config", args)
  defp run_mix_task(["init" | args]), do: Mix.Task.rerun("xamal.init", args)
  defp run_mix_task(["docs" | args]), do: Mix.Task.rerun("xamal.docs", args)
  defp run_mix_task(["build", "details" | args]), do: Mix.Task.rerun("xamal.build.details", args)
  defp run_mix_task(["secrets", "print" | args]), do: Mix.Task.rerun("xamal.secrets.print", args)

  defp run_mix_task([task | _args]),
    do: Mix.raise("Unknown Mix task mapping for #{inspect(task)}")

  def deploy_config, do: @xamal_config
  def secrets_file, do: @secrets_file
end
