defmodule Xamal.ContextTest do
  use ExUnit.Case, async: true

  alias Xamal.Context

  @config %Xamal.Configuration{
    raw_config: %{"service" => "test-app"},
    roles: [
      %Xamal.Configuration.Role{name: "web", hosts: ["10.0.0.1", "10.0.0.2"]},
      %Xamal.Configuration.Role{name: "worker", hosts: ["10.0.0.3"]}
    ]
  }

  test "returns all hosts without filters" do
    context = Context.new(@config)
    assert Context.hosts(context) == ["10.0.0.1", "10.0.0.2", "10.0.0.3"]
  end

  test "filters hosts by wildcard" do
    context = @config |> Context.new() |> Context.put_specific_hosts(["10.0.0.*"])
    assert Context.hosts(context) == ["10.0.0.1", "10.0.0.2", "10.0.0.3"]
  end

  test "intersects host and role filters" do
    context =
      @config
      |> Context.new()
      |> Context.put_specific_hosts(["10.0.0.3"])
      |> Context.put_specific_roles(["web"])

    assert Context.hosts(context) == []
  end

  test "filters roles" do
    context = @config |> Context.new() |> Context.put_specific_roles(["worker"])
    assert Enum.map(Context.roles(context), & &1.name) == ["worker"]
  end
end
