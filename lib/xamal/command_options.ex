defmodule Xamal.CommandOptions do
  @moduledoc false

  require Logger

  alias Xamal.{Commander, Configuration}

  def apply_filters_and_verbosity(opts) do
    configure_host_filter(opts)
    configure_role_filter(opts)
    configure_primary_filter(opts)
    configure_verbosity(opts)
  end

  defp configure_host_filter(opts) do
    if hosts = Keyword.get(opts, :hosts) do
      hosts |> String.split(",") |> Commander.set_specific_hosts()
    end
  end

  defp configure_role_filter(opts) do
    if roles = Keyword.get(opts, :roles) do
      roles |> String.split(",") |> Commander.set_specific_roles()
    end
  end

  defp configure_primary_filter(opts) do
    if Keyword.get(opts, :primary) do
      Commander.config()
      |> primary_host()
      |> set_primary_host()
    end
  end

  defp primary_host(nil), do: nil
  defp primary_host(config), do: Configuration.primary_host(config)

  defp set_primary_host(nil), do: :ok
  defp set_primary_host(primary), do: Commander.set_specific_hosts([primary])

  defp configure_verbosity(opts) do
    cond do
      Keyword.get(opts, :verbose) ->
        Commander.set_verbosity(:debug)
        Logger.configure(level: :debug)

      Keyword.get(opts, :quiet) ->
        Commander.set_verbosity(:error)
        Logger.configure(level: :error)

      true ->
        :ok
    end
  end
end
