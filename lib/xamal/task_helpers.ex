defmodule Xamal.TaskHelpers do
  @moduledoc false

  import Xamal.Output

  def ensure_clean_git!(opts) do
    unless Keyword.get(opts, :skip_dirty_check, false) do
      if Xamal.Utils.git_dirty?() do
        Mix.raise(
          "Deploy aborted: uncommitted changes detected. Commit your changes or use --skip-dirty-check to deploy anyway."
        )
      end
    end
  end

  def print_runtime(fun) do
    started_at = System.monotonic_time(:millisecond)
    result = fun.()
    elapsed = (System.monotonic_time(:millisecond) - started_at) / 1000
    say("  Finished all in #{:erlang.float_to_binary(elapsed, decimals: 1)} seconds")
    result
  end

  def confirming(question, opts, fun) do
    if Keyword.get(opts, :confirmed, false) do
      fun.()
    else
      IO.write("#{question} [y/N] ")

      case IO.gets("") |> String.trim() |> String.downcase() do
        "y" -> fun.()
        _ -> say("Aborted", :red)
      end
    end
  end
end
