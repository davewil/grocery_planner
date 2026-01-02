%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "src/",
          "test/",
          "web/",
          "apps/*/lib/",
          "apps/*/src/",
          "apps/*/test/",
          "apps/*/web/"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      strict: true,
      checks: %{
        disabled: [
          # Disable nested module aliasing suggestion - this is overly strict
          {Credo.Check.Design.AliasUsage, []},
          # Allow explicit try blocks - sometimes they're clearer
          {Credo.Check.Readability.PreferImplicitTry, []}
        ]
      }
    }
  ]
}
