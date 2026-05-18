defmodule Xamal.Build do
  @moduledoc """
  Release build and distribution task implementations.
  """

  import Xamal.Shell

  alias Xamal.{Commander, Configuration, SSH}
  alias Xamal.Commands.{Base, Builder}
  alias Xamal.Configuration.Builder, as: BuildConfig

  def run(subcommand, args, opts) do
    case subcommand do
      "deliver" -> deliver(args, opts)
      "push" -> push(args, opts)
      "pull" -> pull(args, opts)
      "details" -> details(args, opts)
      other -> say("Unknown build command: #{other}", :red)
    end
  end

  def deliver(_args, opts) do
    skip_hooks = Keyword.get(opts, :skip_hooks, false)
    run_hook("pre-build", skip_hooks: skip_hooks)
    push([], opts)
    run_hook("post-build", skip_hooks: skip_hooks)
    pull([], opts)
  end

  def push(_args, _opts) do
    config = Commander.config()
    docker? = BuildConfig.docker?(config.builder)

    if docker? do
      verify_docker_available!()
      image = BuildConfig.docker_image(config.builder)
      say("Building release in Docker (#{image})...", :magenta)
    else
      say("Building release locally...", :magenta)
    end

    build_cmd =
      if docker? do
        Builder.build_in_docker(config)
      else
        Builder.build_release(config)
      end

    cmd_str = Base.to_command_string(build_cmd)

    case System.cmd("sh", ["-c", cmd_str], stderr_to_stdout: true, into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        say("Release built successfully", :green)

        say("Creating tarball...", :magenta)
        tarball_cmd = Builder.create_tarball(config)
        tarball_str = Base.to_command_string(tarball_cmd)

        case System.cmd("sh", ["-c", tarball_str], stderr_to_stdout: true) do
          {_, 0} -> say("Tarball created: #{Builder.tarball_path(config)}", :green)
          {output, _} -> raise "Failed to create tarball: #{output}"
        end

      {_, code} when docker? ->
        image = BuildConfig.docker_image(config.builder)

        raise """
        Docker build failed with exit code #{code}.

        Image: #{image}

        This usually means:
          - The Docker image does not exist on the registry (check the tag)
          - Docker cannot pull the image (check network/auth)
          - The build commands failed inside the container

        To debug, try:
          docker pull #{image}
        """

      {_, code} ->
        raise "Build failed with exit code #{code}"
    end
  end

  defp verify_docker_available! do
    case System.cmd("docker", ["info"], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {_, _} ->
        raise """
        Docker is not available.

        The builder is configured to use Docker but the 'docker' command is not \
        working. Make sure Docker is installed and running.
        """
    end
  rescue
    e in ErlangError ->
      reraise RuntimeError,
              [
                message: """
                Docker is not installed.

                The builder is configured to use Docker but the 'docker' command was not \
                found. Install Docker to use Docker-based builds, or remove the 'docker' \
                setting from your builder configuration.

                Original error: #{inspect(e)}
                """
              ],
              __STACKTRACE__
  end

  def pull(_args, _opts) do
    config = Commander.config()
    hosts = Commander.hosts()

    tarball_path = Builder.tarball_path(config)

    unless File.exists?(tarball_path) do
      raise "Tarball not found at #{tarball_path}. Run 'mix xamal.build.push' first."
    end

    Enum.each(hosts, fn host ->
      say("  Uploading to #{host}...", :magenta)

      version = config.version
      remote_dir = "#{Configuration.releases_directory(config)}/#{version}"

      # Create remote directory
      mkdir_cmd = Base.make_directory(remote_dir)
      SSH.execute_command(host, mkdir_cmd, ssh_config: config.ssh)

      # Upload via SFTP (works with key_data)
      remote_path = "#{remote_dir}/#{Builder.tarball_name(config)}"

      case SSH.upload(host, tarball_path, remote_path, ssh_config: config.ssh) do
        {:ok, _} ->
          # Unpack on remote
          unpack_cmd = Builder.unpack_tarball(config)
          SSH.execute_command(host, unpack_cmd, ssh_config: config.ssh)
          say("  Deployed to #{host}", :green)

        {:error, reason} ->
          raise "Failed to upload to #{host}: #{inspect(reason)}"
      end
    end)
  end

  def details(_args, _opts) do
    config = Commander.config()

    IO.puts("Build configuration:")
    IO.puts("  Release name: #{config.release.name}")
    IO.puts("  Mix env: #{config.release.mix_env}")
    IO.puts("  Version: #{config.version}")
    IO.puts("  Builder: #{builder_type(config.builder)}")
    IO.puts("  Tarball: #{Builder.tarball_path(config)}")
  end

  def help do
    IO.puts("""
    Use `mix help | grep xamal.build` to list build tasks.

    Commands:
      deliver    Build release locally and distribute to servers
      push       Build release locally
      pull       Upload tarball to servers
      details    Show build configuration
    """)
  end

  defp builder_type(builder) do
    cond do
      BuildConfig.docker?(builder) -> "docker"
      BuildConfig.remote?(builder) -> "remote (#{builder.remote})"
      true -> "local"
    end
  end
end
