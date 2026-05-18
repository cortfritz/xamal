defmodule Xamal.Commander do
  @moduledoc """
  Agent-backed runtime context for CLI compatibility.

  New orchestration code should prefer passing `%Xamal.Context{}` explicitly.
  """

  use Agent

  alias Xamal.Context

  def start_link(opts \\ []) do
    Agent.start_link(fn -> Context.new() end, name: Keyword.get(opts, :name, __MODULE__))
  end

  def configure(config, opts \\ []) do
    update(opts, &Context.put_config(&1, config))
  end

  def config(name \\ __MODULE__) do
    name |> get_context() |> Map.get(:config)
  end

  def context(name \\ __MODULE__), do: get_context(name)

  def configured?(name \\ __MODULE__) do
    name |> get_context() |> Context.configured?()
  end

  def set_specific_hosts(hosts, name \\ __MODULE__) do
    update([name: name], &Context.put_specific_hosts(&1, hosts))
  end

  def set_specific_roles(roles, name \\ __MODULE__) do
    update([name: name], &Context.put_specific_roles(&1, roles))
  end

  def set_verbosity(verbosity, name \\ __MODULE__) do
    update([name: name], &Context.put_verbosity(&1, verbosity))
  end

  def holding_lock?(name \\ __MODULE__) do
    name |> get_context() |> Map.get(:holding_lock)
  end

  def set_holding_lock(value, name \\ __MODULE__) do
    update([name: name], &Context.put_holding_lock(&1, value))
  end

  def connected?(name \\ __MODULE__) do
    name |> get_context() |> Map.get(:connected)
  end

  def set_connected(value, name \\ __MODULE__) do
    update([name: name], &Context.put_connected(&1, value))
  end

  def hosts(name \\ __MODULE__) do
    name |> get_context() |> Context.hosts()
  end

  def primary_host(name \\ __MODULE__) do
    name |> get_context() |> Context.primary_host()
  end

  def roles(name \\ __MODULE__) do
    name |> get_context() |> Context.roles()
  end

  defp get_context(name), do: Agent.get(name, & &1)

  defp update(opts, fun) do
    opts
    |> Keyword.get(:name, __MODULE__)
    |> Agent.update(fun)
  end
end
