defmodule Xamal.Init do
  @moduledoc false

  alias Igniter.Project.MixProject
  alias Rewrite.Source

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
    if Code.ensure_loaded?(Mix) and File.exists?("mix.exs") do
      Application.ensure_all_started(:rewrite)

      result =
        Igniter.new()
        |> add_config()
        |> add_secrets()
        |> add_hooks()
        |> add_gitignore_entries()
        |> add_release_config()
        |> add_mix_aliases()
        |> add_health_route_notice()
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
    create_unless_exists(igniter, "config/xamal.exs", config_template(project_app()))
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

  def add_gitignore_entries(igniter) do
    entries = [".xamal/secrets*", ".xamal/*.env"]

    Igniter.create_or_update_file(
      igniter,
      ".gitignore",
      IO.iodata_to_binary([Enum.intersperse(entries, "\n"), "\n"]),
      &update_gitignore(&1, entries)
    )
  end

  def add_release_config(igniter) do
    app = project_app()

    MixProject.update(igniter, :project, [:releases, app], fn
      nil -> {:ok, {:code, [version: {:from_app, app}]}}
      zipper -> {:ok, zipper}
    end)
  end

  def add_mix_aliases(igniter) do
    MixProject.update(igniter, :project, [:aliases, :"xamal.info"], fn
      nil -> {:ok, {:code, ["xamal.config"]}}
      zipper -> {:ok, zipper}
    end)
  end

  def add_health_route_notice(igniter) do
    if phoenix_project?() do
      Igniter.add_notice(
        igniter,
        "Phoenix project detected. Add a lightweight health route matching xamal's health_check.path, for example GET /health returning 200."
      )
    else
      igniter
    end
  end

  defp update_gitignore(source, entries) do
    content = source.content || ""
    missing = Enum.reject(entries, &gitignore_entry?(content, &1))

    if missing == [] do
      source
    else
      Source.update(source, :content, gitignore_content(content, missing))
    end
  end

  defp gitignore_content(content, missing) do
    separator = if String.ends_with?(content, "\n") or content == "", do: "", else: "\n"
    IO.iodata_to_binary([content, separator, Enum.intersperse(missing, "\n"), "\n"])
  end

  defp gitignore_entry?(content, entry) do
    content
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.member?(entry)
  end

  defp project_app do
    if Code.ensure_loaded?(Mix.Project) and Mix.Project.get() do
      Mix.Project.config() |> Keyword.fetch!(:app)
    else
      :my_app
    end
  end

  defp phoenix_project? do
    deps = Keyword.get(Mix.Project.config(), :deps, [])
    Enum.any?(deps, &phoenix_dep?/1)
  rescue
    _ -> false
  end

  defp phoenix_dep?({:phoenix, _requirement}), do: true
  defp phoenix_dep?({:phoenix, _requirement, _opts}), do: true
  defp phoenix_dep?(_dep), do: false

  defp config_template(app) do
    release = Atom.to_string(app)
    service = String.replace(release, "_", "-")

    """
    import Config

    config :xamal,
      service: #{inspect(service)},
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
        name: #{inspect(release)},
        mix_env: "prod"
      ],
      health_check: [
        path: "/health"
      ]
    """
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
      config_template(project_app()),
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
