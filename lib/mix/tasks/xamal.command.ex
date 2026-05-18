defmodule Xamal.MixTask.Command do
  @moduledoc false

  defmacro __using__(command) do
    quote bind_quoted: [command: command] do
      use Mix.Task

      @impl true
      def run(args) do
        Xamal.CLI.main([unquote(command) | args])
      end
    end
  end
end
