defmodule GroceryPlanner.Recipes.RecipeCalculationsTest do
  use GroceryPlanner.DataCase, async: true

  import GroceryPlanner.InventoryTestHelpers

  alias GroceryPlanner.Recipes

  describe "ingredient_availability calculation" do
    test "returns 100% when recipe has no ingredients" do
      {account, user} = create_account_and_user()

      {:ok, recipe} =
        Recipes.create_recipe(
          account.id,
          %{name: "Empty Recipe"},
          authorize?: false,
          tenant: account.id
        )

      recipe_with_calc =
        Recipes.get_recipe!(recipe.id,
          authorize?: false,
          tenant: account.id,
          load: [:ingredient_availability]
        )

      assert Decimal.eq?(recipe_with_calc.ingredient_availability, Decimal.new("100.0"))
    end

    test "returns correct percentage when some ingredients are available" do
      {account, user} = create_account_and_user()

      # Create recipe with 3 ingredients
      {:ok, recipe} = create_recipe_with_name(account, user, "Test Recipe")

      # Create 3 grocery items
      item1 = create_item_with_inventory(account, user, "Flour")
      item2 = create_item_with_inventory(account, user, "Sugar")
      item3 = create_grocery_item(account, user, %{name: "Eggs"})

      # Add all 3 as recipe ingredients
      create_recipe_ingredient(account, user, recipe, item1)
      create_recipe_ingredient(account, user, recipe, item2)
      create_recipe_ingredient(account, user, recipe, item3)

      recipe_with_calc =
        Recipes.get_recipe!(recipe.id,
          authorize?: false,
          tenant: account.id,
          load: [:ingredient_availability]
        )

      # 2 out of 3 ingredients = 66.67%
      expected = Decimal.div(Decimal.new(2), Decimal.new(3)) |> Decimal.mult(Decimal.new("100"))
      assert Decimal.eq?(recipe_with_calc.ingredient_availability, expected)
    end

    test "returns 100% when all ingredients are available" do
      {account, user} = create_account_and_user()

      {:ok, recipe} = create_recipe_with_name(account, user, "Fully Stocked Recipe")

      item1 = create_item_with_inventory(account, user, "Butter")
      item2 = create_item_with_inventory(account, user, "Milk")

      create_recipe_ingredient(account, user, recipe, item1)
      create_recipe_ingredient(account, user, recipe, item2)

      recipe_with_calc =
        Recipes.get_recipe!(recipe.id,
          authorize?: false,
          tenant: account.id,
          load: [:ingredient_availability]
        )

      assert Decimal.eq?(recipe_with_calc.ingredient_availability, Decimal.new("100.0"))
    end
  end

  describe "can_make calculation" do
    test "returns true when recipe has no ingredients" do
      {account, user} = create_account_and_user()

      {:ok, recipe} =
        Recipes.create_recipe(
          account.id,
          %{name: "Empty Recipe"},
          authorize?: false,
          tenant: account.id
        )

      recipe_with_calc =
        Recipes.get_recipe!(recipe.id,
          authorize?: false,
          tenant: account.id,
          load: [:can_make]
        )

      assert recipe_with_calc.can_make == true
    end

    test "returns false when required ingredients are missing" do
      {account, user} = create_account_and_user()

      {:ok, recipe} = create_recipe_with_name(account, user, "Missing Ingredients")

      item1 = create_item_with_inventory(account, user, "Ingredient1")
      item2 = create_grocery_item(account, user, %{name: "Ingredient2"})

      create_recipe_ingredient(account, user, recipe, item1)
      create_recipe_ingredient(account, user, recipe, item2)

      recipe_with_calc =
        Recipes.get_recipe!(recipe.id,
          authorize?: false,
          tenant: account.id,
          load: [:can_make]
        )

      assert recipe_with_calc.can_make == false
    end

    test "returns true when all required ingredients are available" do
      {account, user} = create_account_and_user()

      {:ok, recipe} = create_recipe_with_name(account, user, "Makeable Recipe")

      item1 = create_item_with_inventory(account, user, "AvailableItem1")
      item2 = create_item_with_inventory(account, user, "AvailableItem2")

      create_recipe_ingredient(account, user, recipe, item1)
      create_recipe_ingredient(account, user, recipe, item2)

      recipe_with_calc =
        Recipes.get_recipe!(recipe.id,
          authorize?: false,
          tenant: account.id,
          load: [:can_make]
        )

      assert recipe_with_calc.can_make == true
    end

    test "returns true when only optional ingredients are missing" do
      {account, user} = create_account_and_user()

      {:ok, recipe} = create_recipe_with_name(account, user, "Recipe with Optional")

      required_item = create_item_with_inventory(account, user, "RequiredItem")
      optional_item = create_grocery_item(account, user, %{name: "OptionalItem"})

      create_recipe_ingredient(account, user, recipe, required_item, is_optional: false)
      create_recipe_ingredient(account, user, recipe, optional_item, is_optional: true)

      recipe_with_calc =
        Recipes.get_recipe!(recipe.id,
          authorize?: false,
          tenant: account.id,
          load: [:can_make]
        )

      assert recipe_with_calc.can_make == true
    end
  end

  describe "missing_ingredients calculation" do
    test "returns empty list when all ingredients are available" do
      {account, user} = create_account_and_user()

      {:ok, recipe} = create_recipe_with_name(account, user, "Complete Recipe")

      item1 = create_item_with_inventory(account, user, "Item1")
      item2 = create_item_with_inventory(account, user, "Item2")

      create_recipe_ingredient(account, user, recipe, item1)
      create_recipe_ingredient(account, user, recipe, item2)

      recipe_with_calc =
        Recipes.get_recipe!(recipe.id,
          authorize?: false,
          tenant: account.id,
          load: [:missing_ingredients]
        )

      assert recipe_with_calc.missing_ingredients == []
    end

    test "returns list of missing ingredient names" do
      {account, user} = create_account_and_user()

      {:ok, recipe} = create_recipe_with_name(account, user, "Incomplete Recipe")

      available = create_item_with_inventory(account, user, "Available Ingredient")
      missing1 = create_grocery_item(account, user, %{name: "Missing Ingredient 1"})
      missing2 = create_grocery_item(account, user, %{name: "Missing Ingredient 2"})

      create_recipe_ingredient(account, user, recipe, available)
      create_recipe_ingredient(account, user, recipe, missing1)
      create_recipe_ingredient(account, user, recipe, missing2)

      recipe_with_calc =
        Recipes.get_recipe!(recipe.id,
          authorize?: false,
          tenant: account.id,
          load: [:missing_ingredients]
        )

      assert length(recipe_with_calc.missing_ingredients) == 2
      assert "Missing Ingredient 1" in recipe_with_calc.missing_ingredients
      assert "Missing Ingredient 2" in recipe_with_calc.missing_ingredients
    end

    test "excludes optional ingredients from missing list" do
      {account, user} = create_account_and_user()

      {:ok, recipe} = create_recipe_with_name(account, user, "Recipe with Optionals")

      required_missing = create_grocery_item(account, user, %{name: "Required Missing"})
      optional_missing = create_grocery_item(account, user, %{name: "Optional Missing"})

      create_recipe_ingredient(account, user, recipe, required_missing, is_optional: false)
      create_recipe_ingredient(account, user, recipe, optional_missing, is_optional: true)

      recipe_with_calc =
        Recipes.get_recipe!(recipe.id,
          authorize?: false,
          tenant: account.id,
          load: [:missing_ingredients]
        )

      assert recipe_with_calc.missing_ingredients == ["Required Missing"]
      refute "Optional Missing" in recipe_with_calc.missing_ingredients
    end
  end

  defp create_recipe_with_name(account, _user, name) do
    Recipes.create_recipe(
      account.id,
      %{name: name},
      authorize?: false,
      tenant: account.id
    )
  end

  defp create_recipe_ingredient(account, _user, recipe, grocery_item, opts \\ []) do
    is_optional = Keyword.get(opts, :is_optional, false)

    Recipes.create_recipe_ingredient(
      account.id,
      %{
        recipe_id: recipe.id,
        grocery_item_id: grocery_item.id,
        quantity: Decimal.new("1.0"),
        unit: "cup",
        is_optional: is_optional
      },
      authorize?: false,
      tenant: account.id
    )
  end

  defp create_item_with_inventory(account, user, name) do
    item = create_grocery_item(account, user, %{name: name})

    location =
      create_storage_location(account, user, %{name: "Pantry #{System.unique_integer()}"})

    _entry =
      create_inventory_entry(account, user, item, %{
        storage_location_id: location.id,
        quantity: Decimal.new("10.0"),
        unit: "units",
        status: :available
      })

    item
  end
end
