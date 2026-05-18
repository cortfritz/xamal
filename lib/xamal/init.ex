defmodule Xamal.Init do
  @moduledoc false

  @hooks ~w(
    pre-build
    post-build
    pre-deploy
    post-deploy
    pre-app-boot
    post-app-boot
    pre-caddy-reload
    post-caddy-reload
  )

  def run(opts \\ []) do
    if Code.ensure_loaded?(Mix) do
      Application.ensure_all_started(:rewrite)

      result =
        Igniter.new()
        |> add_config()
        |> add_secrets()
        |> add_hooks()
        |> Igniter.do_or_dry_run(
          yes: Keyword.get(opts, :yes, true),
          dry_run: Keyword.get(opts, :dry_run, false),
          title: "mix xamal.init"
        )

      unless Keyword.get(opts, :dry_run, false) do
        make_hooks_executable()
      end

      result
    else
      write_files()
    end
  end

  def add_config(igniter) do
    create_unless_exists(igniter, "config/xamal.exs", config_template())
  end

  def add_secrets(igniter) do
    create_unless_exists(igniter, ".xamal/secrets", secrets_template())
  end

  def add_hooks(igniter) do
    Enum.reduce(@hooks, igniter, fn hook, igniter ->
      create_unless_exists(igniter, ".xamal/hooks/#{hook}", hook_template(hook))
    end)
  end

  defp create_unless_exists(igniter, path, content) do
    if File.exists?(path) do
      igniter
    else
      Igniter.create_new_file(igniter, path, content)
    end
  end

  defp config_template do
    ~S'''
    import Config

    config :xamal,
      service: "my-app",
      servers: [
        web: ["192.168.0.1"]
      ],
      ssh: [
        user: "deploy"
      ],
      caddy: [
        host: "app.example.com",
        app_port: 4000
      ],
      env: [
        clear: [
          PHX_HOST: "app.example.com"
        ],
        secret: [
          "SECRET_KEY_BASE"
        ]
      ],
      release: [
        name: "my_app",
        mix_env: "prod"
      ],
      health_check: [
        path: "/health"
      ]
    '''
  end

  defp secrets_template do
    """
    # Secrets are loaded from this file and made available as env vars on the server.
    # Use command substitution to fetch secrets from a vault:
    #   SECRET_KEY_BASE=$(op read "op://Vault/Item/Field")

    SECRET_KEY_BASE=change_me
    """
  end

  defp hook_template(name) do
    """
    #!/bin/sh
    echo "Running #{name} hook..."
    """
  end

  defp make_hooks_executable do
    Enum.each(@hooks, fn hook ->
      path = Path.join([".xamal", "hooks", hook])
      if File.exists?(path), do: File.chmod!(path, 0o755)
    end)
  end

  defp write_files do
    write_file(
      "config/xamal.exs",
      config_template(),
      "Created configuration file in config/xamal.exs"
    )

    write_file(".xamal/secrets", secrets_template(), "Created .xamal/secrets file")

    Enum.each(@hooks, fn hook ->
      path = Path.join([".xamal", "hooks", hook])
      write_file(path, hook_template(hook), nil)
      File.chmod!(path, 0o755)
    end)

    IO.puts("Created sample hooks in .xamal/hooks")
  end

  defp write_file(path, content, message) do
    if File.exists?(path) do
      IO.puts("#{path} already exists")
    else
      path |> Path.dirname() |> File.mkdir_p!()
      File.write!(path, content)
      if message, do: IO.puts(message)
    end
  end
end
