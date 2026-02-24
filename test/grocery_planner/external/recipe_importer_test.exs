defmodule GroceryPlanner.External.RecipeImporterTest do
  use ExUnit.Case, async: true

  alias GroceryPlanner.External.RecipeImporter

  describe "parse_measure/1" do
    test "parses numeric with unit" do
      assert {1.0, "cup"} = RecipeImporter.parse_measure("1 cup")
    end

    test "parses decimal with unit" do
      assert {1.5, "kg"} = RecipeImporter.parse_measure("1.5 kg")
    end

    test "parses number only" do
      assert {3.0, ""} = RecipeImporter.parse_measure("3")
    end

    test "parses text only as unit with default quantity" do
      assert {1.0, "pinch"} = RecipeImporter.parse_measure("pinch")
    end

    test "handles nil input" do
      assert {1.0, ""} = RecipeImporter.parse_measure(nil)
    end

    test "handles empty string" do
      assert {1.0, ""} = RecipeImporter.parse_measure("")
    end

    test "trims whitespace" do
      assert {2.0, "tbsp"} = RecipeImporter.parse_measure("  2 tbsp  ")
    end
  end
end
