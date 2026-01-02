defmodule GroceryPlanner.Notifications.RecipeSuggestionsTest do
  use GroceryPlanner.DataCase, async: true

  alias GroceryPlanner.Notifications.RecipeSuggestions
  alias GroceryPlanner.InventoryTestHelpers
  require Ash.Query

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
        create_recipe: create_recipe,
        location: location
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

    test "correctly reflects can_make status based on inventory", %{
      account: account,
      user: user,
      item1: item1,
      item2: item2,
      create_recipe: create_recipe,
      location: location
    } do
      # Recipe D: Uses Item 1 and Item 2
      recipe_d = create_recipe.("Recipe D", [item1, item2], false)

      # Initial state: item1 is expiring (from setup), item2 is expiring (from setup)
      # Wait, setup creates expiring inventory for BOTH item1 and item2.
      # So Recipe D is already makeable.
      # I need to REMOVE item2 inventory to test the 'missing' state.

      # Find and destroy the inventory entry for item2 created in setup
      item2_id = item2.id

      entry =
        GroceryPlanner.Inventory.InventoryEntry
        |> Ash.Query.filter(grocery_item_id == ^item2_id)
        |> Ash.read!(actor: user, tenant: account.id)
        |> List.first()

      Ash.destroy!(entry, actor: user, tenant: account.id)

      {:ok, suggestions_initial} =
        RecipeSuggestions.get_suggestions_for_expiring_items(account.id, user)

      recipe_d_suggestion_initial =
        Enum.find(suggestions_initial, fn s -> s.recipe.id == recipe_d.id end)

      refute recipe_d_suggestion_initial.recipe.can_make

      # Reason format: "Uses X expiring ingredients" (does not explicitly state missing count in reason string apparently)
      assert recipe_d_suggestion_initial.reason =~ "Uses 1 expiring ingredient"

      # Add item2 back to inventory (not necessarily expiring soon, just present)
      InventoryTestHelpers.create_inventory_entry(account, user, item2, %{
        storage_location_id: location.id,
        # Not expiring soon
        use_by_date: Date.add(Date.utc_today(), 100),
        quantity: Decimal.new("5")
      })

      {:ok, suggestions_final} =
        RecipeSuggestions.get_suggestions_for_expiring_items(account.id, user)

      recipe_d_suggestion_final =
        Enum.find(suggestions_final, fn s -> s.recipe.id == recipe_d.id end)

      assert recipe_d_suggestion_final.recipe.can_make
      # Reason format: "Uses X expiring ingredients - ready to cook!"
      # Wait, if item2 is NOT expiring (date + 100), then only item1 is expiring.
      # So "Uses 1 expiring ingredient".
      assert recipe_d_suggestion_final.reason =~ "Uses 1 expiring ingredient - ready to cook!"
    end
  end
end
