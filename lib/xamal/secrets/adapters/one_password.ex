defmodule Xamal.Secrets.Adapters.OnePassword do
  @moduledoc false

  import Xamal.Output
  import Xamal.Secrets.Adapters.Helpers

  def fetch([vault, item, field | _]) do
    shell_cmd(
      "op read op://#{vault}/#{item}/#{field}",
      &trimmed_write/1,
      "1Password fetch failed"
    )
  end

  def fetch(_args) do
    say("Usage: mix xamal.secrets.fetch 1password <vault> <item> <field>", :red)
  end
end
