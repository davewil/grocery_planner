defmodule GroceryPlanner.External.TheMealDBTest do
  use ExUnit.Case, async: true

  alias GroceryPlanner.External.TheMealDB
  alias GroceryPlanner.TheMealDBStubs

  describe "search/2" do
    test "returns parsed meals when API returns results" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.search_chicken/1)

      assert {:ok, meals} = TheMealDB.search("chicken", plug: {Req.Test, TheMealDB})

      assert length(meals) == 2
      assert [meal1, meal2] = meals

      assert meal1.external_id == "52940"
      assert meal1.name == "Brown Stew Chicken"
      assert meal1.category == "Chicken"
      assert meal1.area == "Jamaican"

      assert meal1.image_url ==
               "https://www.themealdb.com/images/media/meals/sypxpx1515365095.jpg"

      assert length(meal1.ingredients) == 3
      assert meal1.tags == ["Stew"]

      assert meal2.external_id == "52795"
      assert meal2.name == "Chicken Handi"
    end

    test "returns empty list when API returns no results" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.search_empty/1)

      assert {:ok, []} = TheMealDB.search("nonexistent", plug: {Req.Test, TheMealDB})
    end

    test "returns error when API returns non-200 status" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.api_error/1)

      assert {:error, "API returned status 500"} =
               TheMealDB.search("error", plug: {Req.Test, TheMealDB})
    end

    test "parses ingredients correctly" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.search_chicken/1)

      assert {:ok, [meal | _]} = TheMealDB.search("chicken", plug: {Req.Test, TheMealDB})

      assert [ing1, ing2, ing3] = meal.ingredients
      assert ing1.name == "Chicken"
      assert ing1.measure == "1 whole"
      assert ing2.name == "Tomato"
      assert ing2.measure == "2"
      assert ing3.name == "Onions"
      assert ing3.measure == "2 chopped"
    end

    test "filters out empty ingredients" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.search_chicken/1)

      assert {:ok, [meal | _]} = TheMealDB.search("chicken", plug: {Req.Test, TheMealDB})

      # Should only have 3 ingredients, empty ones filtered
      assert length(meal.ingredients) == 3
      refute Enum.any?(meal.ingredients, fn ing -> ing.name == "" end)
    end

    test "parses tags correctly when present" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.search_chicken/1)

      assert {:ok, [meal | _]} = TheMealDB.search("chicken", plug: {Req.Test, TheMealDB})

      assert meal.tags == ["Stew"]
    end

    test "returns empty tags list when tags are nil" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.search_chicken/1)

      assert {:ok, [_meal1, meal2]} =
               TheMealDB.search("chicken", plug: {Req.Test, TheMealDB})

      assert meal2.tags == []
    end
  end

  describe "get/2" do
    test "returns parsed meal when found" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.get_meal_by_id/1)

      assert {:ok, meal} = TheMealDB.get("52940", plug: {Req.Test, TheMealDB})

      assert meal.external_id == "52940"
      assert meal.name == "Brown Stew Chicken"
      assert meal.category == "Chicken"
      assert meal.area == "Jamaican"
      assert meal.youtube_url == "https://www.youtube.com/watch?v=1"
      assert meal.source_url == "https://example.com/recipe"
      assert length(meal.ingredients) == 5
      assert meal.tags == ["Stew", "Comfort"]
    end

    test "returns not_found error when meal doesn't exist" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.get_meal_not_found/1)

      assert {:error, :not_found} = TheMealDB.get("99999", plug: {Req.Test, TheMealDB})
    end

    test "returns error when API returns non-200 status" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.api_error/1)

      assert {:error, "API returned status 500"} =
               TheMealDB.get("error", plug: {Req.Test, TheMealDB})
    end
  end

  describe "random/1" do
    test "returns a random meal" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.random_meal/1)

      assert {:ok, meal} = TheMealDB.random(plug: {Req.Test, TheMealDB})

      assert meal.external_id == "52771"
      assert meal.name == "Spicy Arrabiata Penne"
      assert meal.category == "Vegetarian"
      assert meal.area == "Italian"
      assert length(meal.ingredients) == 8
      assert meal.tags == ["Pasta", "Curry"]
    end

    test "returns error when API fails" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.api_error/1)

      assert {:error, "API returned status 500"} =
               TheMealDB.random(plug: {Req.Test, TheMealDB})
    end
  end

  describe "categories/1" do
    test "returns list of categories" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.list_categories/1)

      assert {:ok, categories} = TheMealDB.categories(plug: {Req.Test, TheMealDB})

      assert length(categories) == 3
      assert Enum.any?(categories, fn cat -> cat["strCategory"] == "Beef" end)
      assert Enum.any?(categories, fn cat -> cat["strCategory"] == "Chicken" end)
      assert Enum.any?(categories, fn cat -> cat["strCategory"] == "Dessert" end)
    end

    test "returns error when API fails" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.api_error/1)

      assert {:error, "API returned status 500"} =
               TheMealDB.categories(plug: {Req.Test, TheMealDB})
    end
  end

  describe "filter/2" do
    test "returns meals in the category" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.filter_by_chicken/1)

      assert {:ok, meals} = TheMealDB.filter([c: "Chicken"], plug: {Req.Test, TheMealDB})

      assert length(meals) == 2
      assert Enum.all?(meals, fn meal -> meal.category == "Chicken" end)
    end

    test "returns empty list when no meals in category" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.search_empty/1)

      assert {:ok, []} = TheMealDB.filter([c: "Unknown"], plug: {Req.Test, TheMealDB})
    end

    test "returns error when API fails" do
      Req.Test.stub(TheMealDB, &TheMealDBStubs.api_error/1)

      assert {:error, "API returned status 500"} =
               TheMealDB.filter([c: "Chicken"], plug: {Req.Test, TheMealDB})
    end
  end

  describe "to_recipe_attrs/1" do
    test "converts meal to recipe attributes format" do
      meal = %{
        external_id: "123",
        name: "Test Recipe",
        category: "Chicken",
        area: "Indian",
        instructions: "Cook it well",
        image_url: "https://example.com/image.jpg",
        source_url: "https://example.com/recipe",
        youtube_url: nil,
        ingredients: [
          %{name: "Chicken", measure: "1 lb"},
          %{name: "Onion", measure: "1"}
        ],
        tags: []
      }

      attrs = TheMealDB.to_recipe_attrs(meal)

      assert attrs.name == "Test Recipe"
      assert attrs.description == "Chicken · Indian"
      assert attrs.instructions == "Cook it well"
      assert attrs.image_url == "https://example.com/image.jpg"
      assert attrs.source == "https://example.com/recipe"
      assert attrs.difficulty == :medium
      assert attrs.servings == 4
      assert attrs.is_favorite == false

      # Note: prep_time_minutes and cook_time_minutes are not set (TheMealDB doesn't provide this data)
    end

    test "builds description from category and area" do
      meal = %{
        name: "Test",
        category: "Beef",
        area: "American",
        instructions: nil,
        image_url: nil,
        source_url: nil,
        youtube_url: nil,
        ingredients: [],
        tags: []
      }

      attrs = TheMealDB.to_recipe_attrs(meal)
      assert attrs.description == "Beef · American"
    end

    test "handles missing category or area" do
      meal = %{
        name: "Test",
        category: "Beef",
        area: nil,
        instructions: nil,
        image_url: nil,
        source_url: nil,
        youtube_url: nil,
        ingredients: [],
        tags: []
      }

      attrs = TheMealDB.to_recipe_attrs(meal)
      assert attrs.description == "Beef"
    end

    test "returns nil description when both category and area are missing" do
      meal = %{
        name: "Test",
        category: nil,
        area: nil,
        instructions: nil,
        image_url: nil,
        source_url: nil,
        youtube_url: nil,
        ingredients: [],
        tags: []
      }

      attrs = TheMealDB.to_recipe_attrs(meal)
      assert attrs.description == nil
    end

    test "defaults source to TheMealDB when source_url is nil" do
      meal = %{
        name: "Test",
        category: nil,
        area: nil,
        instructions: nil,
        image_url: nil,
        source_url: nil,
        youtube_url: nil,
        ingredients: [],
        tags: []
      }

      attrs = TheMealDB.to_recipe_attrs(meal)
      assert attrs.source == "TheMealDB"
    end
  end
end
