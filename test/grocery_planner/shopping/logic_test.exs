defmodule GroceryPlanner.Shopping.LogicTest do
  use GroceryPlanner.DataCase, async: true

  alias GroceryPlanner.Shopping
  import GroceryPlanner.InventoryTestHelpers
  import GroceryPlanner.MealPlanningTestHelpers, only: [create_meal_plan: 4]

  setup do
    account = create_account()
    user = create_user(account)
    %{account: account, user: user}
  end

  defp create_recipe_with_ingredients(account, user) do
    # Create ingredients
    item1 = create_grocery_item(account, user, %{name: "Pasta"})
    item2 = create_grocery_item(account, user, %{name: "Tomato Sauce"})

    # Create recipe
    {:ok, recipe} =
      GroceryPlanner.Recipes.create_recipe(
        account.id,
        %{
          name: "Pasta with Sauce",
          servings: 4,
          instructions: "Cook pasta, add sauce."
        },
        actor: user,
        tenant: account.id
      )

    # Add ingredients to recipe
    GroceryPlanner.Recipes.create_recipe_ingredient(
      account.id,
      %{
        recipe_id: recipe.id,
        grocery_item_id: item1.id,
        quantity: Decimal.new("500"),
        unit: "g"
      },
      actor: user,
      tenant: account.id
    )

    GroceryPlanner.Recipes.create_recipe_ingredient(
      account.id,
      %{
        recipe_id: recipe.id,
        grocery_item_id: item2.id,
        quantity: Decimal.new("1"),
        unit: "jar"
      },
      actor: user,
      tenant: account.id
    )

    # Reload recipe with ingredients
    Ash.load!(recipe, [recipe_ingredients: :grocery_item], actor: user, tenant: account.id)
  end

  describe "generate_from_meal_plans" do
    test "generates items from meal plans", %{account: account, user: user} do
      recipe = create_recipe_with_ingredients(account, user)

      # Create meal plan for today
      create_meal_plan(account, user, recipe, %{
        scheduled_date: Date.utc_today(),
        servings: 4
      })

      # Generate shopping list
      {:ok, list} =
        Shopping.generate_shopping_list_from_meal_plans(
          account.id,
          Date.utc_today(),
          Date.utc_today(),
          %{name: "Weekly Shopping"},
          actor: user,
          tenant: account.id
        )

      # Verify list created
      assert list.name == "Weekly Shopping"
      assert list.generated_from == :meal_plan

      # Verify items added
      items = Shopping.list_shopping_list_items!(authorize?: false, tenant: account.id)
      assert length(items) == 2

      pasta = Enum.find(items, &(&1.name == "Pasta"))
      assert pasta
      assert Decimal.equal?(pasta.quantity, Decimal.new("500"))
      assert pasta.unit == "g"

      sauce = Enum.find(items, &(&1.name == "Tomato Sauce"))
      assert sauce
      assert Decimal.equal?(sauce.quantity, Decimal.new("1"))
      assert sauce.unit == "jar"
    end

    test "deducts existing inventory", %{account: account, user: user} do
      recipe = create_recipe_with_ingredients(account, user)
      [ing1, _ing2] = recipe.recipe_ingredients

      # Add some pasta to inventory (200g)
      create_inventory_entry(account, user, ing1.grocery_item, %{
        quantity: Decimal.new("200"),
        # Assuming unit matches for simplicity
        unit: "g"
      })

      # Create meal plan (needs 500g pasta)
      create_meal_plan(account, user, recipe, %{
        scheduled_date: Date.utc_today(),
        servings: 4
      })

      # Generate shopping list
      {:ok, _list} =
        Shopping.generate_shopping_list_from_meal_plans(
          account.id,
          Date.utc_today(),
          Date.utc_today(),
          %{name: "Weekly Shopping"},
          actor: user,
          tenant: account.id
        )

      items = Shopping.list_shopping_list_items!(authorize?: false, tenant: account.id)

      # Pasta should be 300g (500 - 200)
      pasta = Enum.find(items, &(&1.name == "Pasta"))
      assert pasta
      assert Decimal.equal?(pasta.quantity, Decimal.new("300"))

      # Sauce should be 1 jar (none in inventory)
      sauce = Enum.find(items, &(&1.name == "Tomato Sauce"))
      assert sauce
      assert Decimal.equal?(sauce.quantity, Decimal.new("1"))
    end

    test "scales quantities based on servings", %{account: account, user: user} do
      # 4 servings
      recipe = create_recipe_with_ingredients(account, user)

      # Create meal plan for 8 servings (double)
      create_meal_plan(account, user, recipe, %{
        scheduled_date: Date.utc_today(),
        servings: 8
      })

      {:ok, _list} =
        Shopping.generate_shopping_list_from_meal_plans(
          account.id,
          Date.utc_today(),
          Date.utc_today(),
          %{name: "Big Shopping"},
          actor: user,
          tenant: account.id
        )

      items = Shopping.list_shopping_list_items!(authorize?: false, tenant: account.id)

      pasta = Enum.find(items, &(&1.name == "Pasta"))
      # 500 * 2
      assert Decimal.equal?(pasta.quantity, Decimal.new("1000"))
    end
  end
end
