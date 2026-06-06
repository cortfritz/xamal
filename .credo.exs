%{
  configs: [
    %{
      name: "default",
      strict: true,
      files: %{
        included: ["lib/", "test/", "mix.exs"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      checks: %{
        extra: Enum.map(ExSlop.checks(), &{&1, []})
      }
    }
  ]
}
