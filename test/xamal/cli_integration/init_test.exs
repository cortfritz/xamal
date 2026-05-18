defmodule Xamal.MixTaskIntegration.InitTest do
  use ExUnit.Case, async: false
  import Xamal.IntegrationHelpers

  setup do
    dir = setup_temp_dir()
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  test "creates config files with expected content and executable hooks", %{dir: dir} do
    {_output, 0} = xamal(["init"], dir)

    assert File.exists?(Path.join(dir, "config/xamal.exs"))
    assert File.exists?(Path.join(dir, ".xamal/secrets"))

    # All 8 hooks should be created and executable
    for hook <-
          ~w(pre-build post-build pre-deploy post-deploy pre-app-boot post-app-boot pre-caddy-reload post-caddy-reload) do
      path = Path.join(dir, ".xamal/hooks/#{hook}")
      assert File.exists?(path), "Expected hook #{hook} to exist"
      %{mode: mode} = File.stat!(path)
      assert Bitwise.band(mode, 0o111) != 0, "Expected hook #{hook} to be executable"
    end

    content = File.read!(Path.join(dir, "config/xamal.exs"))
    assert content =~ "import Config"
    assert content =~ "service: \"my-app\""
    assert content =~ "servers:"
    assert content =~ "caddy:"
    assert content =~ "release:"
    assert content =~ "health_check:"
  end

  test "does not overwrite existing config", %{dir: dir} do
    setup_config(dir)
    {_output, 0} = xamal(["init"], dir)

    content = File.read!(Path.join(dir, "config/xamal.exs"))
    assert content =~ "test-app"
  end
end
