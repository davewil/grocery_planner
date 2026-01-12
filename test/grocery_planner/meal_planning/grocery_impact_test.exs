defmodule GroceryPlanner.MealPlanning.GroceryImpactTest do
  use GroceryPlanner.DataCase
  alias GroceryPlanner.MealPlanning.GroceryImpact
  alias GroceryPlanner.{Inventory, Recipes, MealPlanning}
  require Ash.Query

  setup do
    account = GroceryPlanner.Accounts.Account |> Ash.Seed.seed!(%{name: "Test Account"})

    user =
      GroceryPlanner.Accounts.User
      |> Ash.Seed.seed!(%{
        email: "test@example.com",
        current_account_id: account.id,
        hashed_password: "hash",
        name: "Test User"
      })

    # Create Membership
    GroceryPlanner.Accounts.AccountMembership
    |> Ash.Seed.seed!(%{user_id: user.id, account_id: account.id})

    # Create Grocery Items
    item_milk = Inventory.GroceryItem |> Ash.Seed.seed!(%{name: "Milk", account_id: account.id})
    item_eggs = Inventory.GroceryItem |> Ash.Seed.seed!(%{name: "Eggs", account_id: account.id})

    # Add inventory
    Inventory.InventoryEntry
    |> Ash.Seed.seed!(%{
      grocery_item_id: item_milk.id,
      # 1 Liter
      quantity: Decimal.new("1.0"),
      unit: "Liter",
      account_id: account.id,
      status: :available
    })

    # Create Recipe
    recipe =
      Recipes.Recipe
      |> Ash.Seed.seed!(%{
        name: "Pancakes",
        servings: 4,
        account_id: account.id,
        total_time_minutes: 20
      })

    # Add Ingredients
    Recipes.RecipeIngredient
    |> Ash.Seed.seed!(%{
      recipe_id: recipe.id,
      grocery_item_id: item_milk.id,
      # Requires 0.5 Liter
      quantity: Decimal.new("0.5"),
      unit: "Liter",
      account_id: account.id
    })

    Recipes.RecipeIngredient
    |> Ash.Seed.seed!(%{
      recipe_id: recipe.id,
      grocery_item_id: item_eggs.id,
      quantity: Decimal.new("2"),
      unit: "Count",
      account_id: account.id
    })

    %{account: account, user: user, recipe: recipe, item_milk: item_milk, item_eggs: item_eggs}
  end

  test "calculates missing items correctly", %{
    account: account,
    user: user,
    recipe: recipe,
    item_milk: _item_milk,
    item_eggs: item_eggs
  } do
    # Create a meal plan
    meal_plan =
      MealPlanning.MealPlan
      |> Ash.Seed.seed!(%{
        recipe_id: recipe.id,
        scheduled_date: Date.utc_today(),
        meal_type: :breakfast,
        servings: 4,
        account_id: account.id
      })

    loaded_meal_plan =
      MealPlanning.MealPlan
      |> Ash.Query.filter(id == ^meal_plan.id)
      |> Ash.Query.load(recipe: [recipe_ingredients: :grocery_item])
      |> Ash.read_one!(actor: user, tenant: account.id)

    impact = GroceryImpact.calculate_impact([loaded_meal_plan], account.id, user)

    # Analysis:
    # Milk: Have 1.0, Need 0.5 -> Surplus 0.5. Should NOT be in impact.
    # Eggs: Have 0, Need 2 -> Missing 2. Should be in impact.

    assert length(impact) == 1
    missing_egg = Enum.find(impact, &(&1.grocery_item_id == item_eggs.id))
    assert missing_egg
    assert Decimal.equal?(missing_egg.quantity, Decimal.new("2"))
  end

  test "scales ingredients by servings", %{
    account: account,
    user: user,
    recipe: recipe,
    item_eggs: item_eggs
  } do
    # Meal plan with DOUBLE servings (8 instead of 4)
    meal_plan =
      MealPlanning.MealPlan
      |> Ash.Seed.seed!(%{
        recipe_id: recipe.id,
        scheduled_date: Date.utc_today(),
        meal_type: :lunch,
        servings: 8,
        account_id: account.id
      })

    loaded_meal_plan =
      MealPlanning.MealPlan
      |> Ash.Query.filter(id == ^meal_plan.id)
      |> Ash.Query.load(recipe: [recipe_ingredients: :grocery_item])
      |> Ash.read_one!(actor: user, tenant: account.id)

    impact = GroceryImpact.calculate_impact([loaded_meal_plan], account.id, user)

    # Eggs: Need 2 for 4 servings. For 8 servings need 4.
    missing_egg = Enum.find(impact, &(&1.grocery_item_id == item_eggs.id))
    assert missing_egg
    assert Decimal.equal?(missing_egg.quantity, Decimal.new("4"))
  end
end
