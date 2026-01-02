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
          # Style preferences - don't fail build
          {Credo.Check.Design.AliasUsage, []},
          {Credo.Check.Design.TagTODO, []},
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.MaxLineLength, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.PreferImplicitTry, []}
        ]
      }
    }
  ]
}
