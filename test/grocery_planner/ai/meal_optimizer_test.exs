defmodule GroceryPlanner.AI.MealOptimizerTest do
  use GroceryPlanner.DataCase

  import GroceryPlanner.InventoryTestHelpers

  import GroceryPlanner.RecipesTestHelpers,
    except: [
      create_account_and_user: 0,
      create_account: 0,
      create_user: 1,
      create_grocery_item: 3
    ]

  alias GroceryPlanner.AI.MealOptimizer

  setup do
    {account, user} = create_account_and_user()
    %{account: account, user: user}
  end

  describe "suggest_for_expiring/3" do
    test "prioritizes recipes using soon-to-expire ingredients", %{account: account, user: user} do
      # Create grocery items
      chicken = create_grocery_item(account, user, %{name: "Chicken"})
      beef = create_grocery_item(account, user, %{name: "Beef"})
      rice = create_grocery_item(account, user, %{name: "Rice"})

      # Chicken expires in 2 days, beef in 6 days, rice not expiring
      create_inventory_entry(account, user, chicken, %{
        quantity: Decimal.new("1"),
        use_by_date: Date.add(Date.utc_today(), 2)
      })

      create_inventory_entry(account, user, beef, %{
        quantity: Decimal.new("1"),
        use_by_date: Date.add(Date.utc_today(), 6)
      })

      create_inventory_entry(account, user, rice, %{
        quantity: Decimal.new("1")
      })

      # Recipe using chicken (urgent) should score higher
      chicken_recipe = create_recipe(account, user, %{name: "Chicken Stir Fry"})

      create_recipe_ingredient(account, user, chicken_recipe, chicken, %{
        quantity: Decimal.new("1"),
        unit: "lb"
      })

      # Recipe using beef (less urgent)
      beef_recipe = create_recipe(account, user, %{name: "Beef Stew"})

      create_recipe_ingredient(account, user, beef_recipe, beef, %{
        quantity: Decimal.new("1"),
        unit: "lb"
      })

      {:ok, suggestions} = MealOptimizer.suggest_for_expiring(account.id, user)

      assert length(suggestions) == 2
      # Chicken recipe should be first (expires sooner = higher urgency)
      first = hd(suggestions)
      assert first.recipe.name == "Chicken Stir Fry"
      assert "Chicken" in first.expiring_used
      assert first.score > 0
    end

    test "returns waste_prevention_score and reason for each suggestion", %{
      account: account,
      user: user
    } do
      item = create_grocery_item(account, user, %{name: "Spinach"})

      create_inventory_entry(account, user, item, %{
        quantity: Decimal.new("1"),
        use_by_date: Date.add(Date.utc_today(), 1)
      })

      recipe = create_recipe(account, user, %{name: "Spinach Salad"})

      create_recipe_ingredient(account, user, recipe, item, %{
        quantity: Decimal.new("1"),
        unit: "bunch"
      })

      {:ok, [suggestion | _]} = MealOptimizer.suggest_for_expiring(account.id, user)

      assert suggestion.score > 0
      assert is_binary(suggestion.reason)
      assert suggestion.reason =~ "expiring ingredient"
      assert is_list(suggestion.expiring_used)
      assert is_list(suggestion.missing)
    end

    test "respects limit option", %{account: account, user: user} do
      # Create 3 expiring items with 3 recipes
      for i <- 1..3 do
        item = create_grocery_item(account, user, %{name: "Item #{i}"})

        create_inventory_entry(account, user, item, %{
          quantity: Decimal.new("1"),
          use_by_date: Date.add(Date.utc_today(), 3)
        })

        recipe = create_recipe(account, user, %{name: "Recipe #{i}"})

        create_recipe_ingredient(account, user, recipe, item, %{
          quantity: Decimal.new("1"),
          unit: "unit"
        })
      end

      {:ok, suggestions} = MealOptimizer.suggest_for_expiring(account.id, user, limit: 2)
      assert length(suggestions) == 2
    end

    test "returns empty list when no expiring items", %{account: account, user: user} do
      item = create_grocery_item(account, user, %{name: "Canned Beans"})

      # No use_by_date = not expiring
      create_inventory_entry(account, user, item, %{quantity: Decimal.new("1")})

      recipe = create_recipe(account, user, %{name: "Bean Soup"})

      create_recipe_ingredient(account, user, recipe, item, %{
        quantity: Decimal.new("1"),
        unit: "can"
      })

      {:ok, suggestions} = MealOptimizer.suggest_for_expiring(account.id, user)
      assert suggestions == []
    end

    test "shows missing ingredients for partially-stocked recipes", %{
      account: account,
      user: user
    } do
      chicken = create_grocery_item(account, user, %{name: "Chicken"})
      lettuce = create_grocery_item(account, user, %{name: "Lettuce"})

      # Only chicken is in stock and expiring
      create_inventory_entry(account, user, chicken, %{
        quantity: Decimal.new("1"),
        use_by_date: Date.add(Date.utc_today(), 2)
      })

      recipe = create_recipe(account, user, %{name: "Chicken Caesar Salad"})

      create_recipe_ingredient(account, user, recipe, chicken, %{
        quantity: Decimal.new("1"),
        unit: "lb"
      })

      create_recipe_ingredient(account, user, recipe, lettuce, %{
        quantity: Decimal.new("1"),
        unit: "head"
      })

      {:ok, [suggestion | _]} = MealOptimizer.suggest_for_expiring(account.id, user)

      assert "Chicken" in suggestion.expiring_used
      # Lettuce should be in missing since it's not in inventory
      assert length(suggestion.missing) > 0
    end
  end

  describe "suggest_for_ingredients/4" do
    test "returns recipes sorted by match score", %{account: account, user: user} do
      chicken = create_grocery_item(account, user, %{name: "Chicken"})
      rice = create_grocery_item(account, user, %{name: "Rice"})
      soy_sauce = create_grocery_item(account, user, %{name: "Soy Sauce"})

      # Recipe using 2 of 3 selected ingredients
      stir_fry = create_recipe(account, user, %{name: "Chicken Stir Fry"})

      create_recipe_ingredient(account, user, stir_fry, chicken, %{
        quantity: Decimal.new("1"),
        unit: "lb"
      })

      create_recipe_ingredient(account, user, stir_fry, rice, %{
        quantity: Decimal.new("1"),
        unit: "cup"
      })

      create_recipe_ingredient(account, user, stir_fry, soy_sauce, %{
        quantity: Decimal.new("2"),
        unit: "tbsp"
      })

      # Recipe using 1 of 3 selected ingredients + another
      pasta = create_recipe(account, user, %{name: "Chicken Pasta"})
      other_item = create_grocery_item(account, user, %{name: "Pasta"})

      create_recipe_ingredient(account, user, pasta, chicken, %{
        quantity: Decimal.new("1"),
        unit: "lb"
      })

      create_recipe_ingredient(account, user, pasta, other_item, %{
        quantity: Decimal.new("1"),
        unit: "box"
      })

      {:ok, suggestions} =
        MealOptimizer.suggest_for_ingredients(
          account.id,
          [chicken.id, rice.id, soy_sauce.id],
          user
        )

      assert length(suggestions) == 2
      # Stir fry uses all 3 selected = 100% match
      first = hd(suggestions)
      assert first.recipe.name == "Chicken Stir Fry"
      assert first.match_score == 1.0
      assert length(first.missing) == 0

      # Pasta uses 1/2 = 50% match
      second = Enum.at(suggestions, 1)
      assert second.recipe.name == "Chicken Pasta"
      assert second.match_score == 0.5
    end

    test "shows missing ingredients for partial matches", %{account: account, user: user} do
      chicken = create_grocery_item(account, user, %{name: "Chicken"})
      lettuce = create_grocery_item(account, user, %{name: "Lettuce"})

      recipe = create_recipe(account, user, %{name: "Chicken Salad"})

      create_recipe_ingredient(account, user, recipe, chicken, %{
        quantity: Decimal.new("1"),
        unit: "lb"
      })

      create_recipe_ingredient(account, user, recipe, lettuce, %{
        quantity: Decimal.new("1"),
        unit: "head"
      })

      {:ok, [suggestion | _]} =
        MealOptimizer.suggest_for_ingredients(account.id, [chicken.id], user)

      assert "Chicken" in suggestion.matched
      assert length(suggestion.missing) == 1
    end

    test "returns empty list when no recipes match", %{account: account, user: user} do
      item = create_grocery_item(account, user, %{name: "Random Item"})

      # Create a recipe that doesn't use this item
      other = create_grocery_item(account, user, %{name: "Other"})
      recipe = create_recipe(account, user, %{name: "Other Recipe"})

      create_recipe_ingredient(account, user, recipe, other, %{
        quantity: Decimal.new("1"),
        unit: "unit"
      })

      {:ok, suggestions} =
        MealOptimizer.suggest_for_ingredients(account.id, [item.id], user)

      assert suggestions == []
    end

    test "handles single ingredient selection", %{account: account, user: user} do
      chicken = create_grocery_item(account, user, %{name: "Chicken"})

      recipe = create_recipe(account, user, %{name: "Simple Chicken"})

      create_recipe_ingredient(account, user, recipe, chicken, %{
        quantity: Decimal.new("1"),
        unit: "lb"
      })

      {:ok, [suggestion | _]} =
        MealOptimizer.suggest_for_ingredients(account.id, [chicken.id], user)

      assert suggestion.match_score == 1.0
      assert "Chicken" in suggestion.matched
    end
  end
end
