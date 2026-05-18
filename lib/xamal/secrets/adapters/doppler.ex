defmodule Xamal.Secrets.Adapters.Doppler do
  @moduledoc false

  import Xamal.Secrets.Adapters.Helpers

  def fetch(args) do
    project = Enum.at(args, 0, "")
    config_name = Enum.at(args, 1, "")
    cmd = "doppler secrets download --no-file --format env -p #{project} -c #{config_name}"

    shell_cmd(cmd, &IO.puts/1, "Doppler fetch failed")
  end
end
