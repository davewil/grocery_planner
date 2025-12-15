defmodule GroceryPlanner.Notifications.RecipeSuggestionsTest do
  use GroceryPlanner.DataCase, async: true

  alias GroceryPlanner.Notifications.RecipeSuggestions
  alias GroceryPlanner.InventoryTestHelpers

  describe "recipe suggestions" do
    setup do
      {account, user} = InventoryTestHelpers.create_account_and_user()
      category = InventoryTestHelpers.create_category(account, user)
      location = InventoryTestHelpers.create_storage_location(account, user)

      # Create ingredients
      item1 =
        InventoryTestHelpers.create_grocery_item(account, user, %{
          name: "Item 1",
          category_id: category.id
        })

      item2 =
        InventoryTestHelpers.create_grocery_item(account, user, %{
          name: "Item 2",
          category_id: category.id
        })

      item3 =
        InventoryTestHelpers.create_grocery_item(account, user, %{
          name: "Item 3",
          category_id: category.id
        })

      # Create expiring inventory for Item 1 and Item 2
      today = Date.utc_today()

      InventoryTestHelpers.create_inventory_entry(account, user, item1, %{
        storage_location_id: location.id,
        use_by_date: today,
        quantity: Decimal.new("5")
      })

      InventoryTestHelpers.create_inventory_entry(account, user, item2, %{
        storage_location_id: location.id,
        use_by_date: Date.add(today, 1),
        quantity: Decimal.new("5")
      })

      # Helper to create recipe with ingredients
      create_recipe = fn name, items, is_favorite ->
        {:ok, recipe} =
          GroceryPlanner.Recipes.Recipe
          |> Ash.Changeset.for_create(:create, %{
            name: name,
            description: "Test",
            instructions: "Test",
            prep_time_minutes: 10,
            cook_time_minutes: 10,
            servings: 4,
            difficulty: :easy,
            is_favorite: is_favorite,
            account_id: account.id
          })
          |> Ash.create(authorize?: false, actor: user, tenant: account.id)

        Enum.each(items, fn item ->
          GroceryPlanner.Recipes.RecipeIngredient
          |> Ash.Changeset.for_create(:create, %{
            recipe_id: recipe.id,
            grocery_item_id: item.id,
            quantity: Decimal.new("1"),
            unit: "unit",
            account_id: account.id
          })
          |> Ash.create(authorize?: false, actor: user, tenant: account.id)
        end)

        recipe
      end

      %{
        account: account,
        user: user,
        item1: item1,
        item2: item2,
        item3: item3,
        create_recipe: create_recipe
      }
    end

    test "ranks recipes by expiring ingredients count", %{
      account: account,
      user: user,
      item1: item1,
      item2: item2,
      item3: item3,
      create_recipe: create_recipe
    } do
      # Recipe A: Uses Item 1 and Item 2 (Score 2)
      create_recipe.("Recipe A", [item1, item2], false)

      # Recipe B: Uses only Item 1 (Score 1)
      create_recipe.("Recipe B", [item1], false)

      # Recipe C: Uses Item 1, Item 2, and Item 3 (Score 2, but missing Item 3)
      create_recipe.("Recipe C", [item1, item2, item3], false)

      {:ok, suggestions} = RecipeSuggestions.get_suggestions_for_expiring_items(account.id, user)

      assert length(suggestions) == 3

      # Top should be Recipe A (Score 2, Can Make)
      # Then Recipe C (Score 2, Cannot Make - missing Item 3)
      # Then Recipe B (Score 1, Can Make)

      [first, second, third] = suggestions

      assert first.recipe.name == "Recipe A"
      assert first.score == 2
      assert first.reason =~ "Uses 2 expiring ingredients"

      assert second.recipe.name == "Recipe C"
      assert second.score == 2

      assert third.recipe.name == "Recipe B"
      assert third.score == 1
    end

    test "prioritizes favorites when scores are equal", %{
      account: account,
      user: user,
      item1: item1,
      create_recipe: create_recipe
    } do
      # Recipe A: Uses Item 1, Not Favorite
      create_recipe.("Recipe A", [item1], false)

      # Recipe B: Uses Item 1, Favorite
      create_recipe.("Recipe B", [item1], true)

      {:ok, suggestions} = RecipeSuggestions.get_suggestions_for_expiring_items(account.id, user)

      assert length(suggestions) == 2
      [first, second] = suggestions

      assert first.recipe.name == "Recipe B"
      assert second.recipe.name == "Recipe A"
    end

    test "filters out recipes with 0 score", %{
      account: account,
      user: user,
      item3: item3,
      create_recipe: create_recipe
    } do
      # Recipe using only non-expiring item
      create_recipe.("Recipe Non-Expiring", [item3], false)

      {:ok, suggestions} = RecipeSuggestions.get_suggestions_for_expiring_items(account.id, user)

      assert length(suggestions) == 0
    end
  end
end
