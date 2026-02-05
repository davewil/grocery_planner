defmodule GroceryPlannerWeb.MealOptimizationTest do
  use GroceryPlannerWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import GroceryPlanner.InventoryTestHelpers
  alias GroceryPlanner.Recipes

  setup do
    account = create_account()
    user = create_user(account)

    conn =
      build_conn()
      |> init_test_session(%{
        user_id: user.id,
        account_id: account.id
      })

    %{conn: conn, account: account, user: user}
  end

  defp create_recipe_with_ingredient(account, _user, recipe_name, item) do
    {:ok, recipe} =
      Recipes.create_recipe(
        account.id,
        %{
          name: recipe_name,
          description: "Test recipe",
          instructions: "Cook it.",
          prep_time_minutes: 10,
          cook_time_minutes: 20,
          servings: 4,
          difficulty: :medium
        },
        authorize?: false,
        tenant: account.id
      )

    {:ok, _ingredient} =
      Recipes.create_recipe_ingredient(
        account.id,
        %{
          recipe_id: recipe.id,
          grocery_item_id: item.id,
          quantity: Decimal.new("1"),
          unit: "lb"
        },
        authorize?: false,
        tenant: account.id
      )

    recipe
  end

  defp create_expiring_item(account, user, name, days_ahead) do
    item = create_grocery_item(account, user, %{name: name})

    create_inventory_entry(account, user, item, %{
      quantity: Decimal.new("1"),
      use_by_date: Date.add(Date.utc_today(), days_ahead)
    })

    item
  end

  describe "Dashboard Waste Watch" do
    test "shows Waste Watch widget when items are expiring", %{
      conn: conn,
      account: account,
      user: user
    } do
      _item = create_expiring_item(account, user, "Milk", 2)

      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "Waste Watch"
      assert html =~ "items expiring soon"
      assert html =~ "Get Rescue Plan"
    end

    test "does not show Waste Watch when no items are expiring", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      refute html =~ "items expiring soon"
      refute html =~ "Get Rescue Plan"
    end

    test "Get Rescue Plan loads optimization suggestions", %{
      conn: conn,
      account: account,
      user: user
    } do
      item = create_expiring_item(account, user, "Chicken", 2)
      _recipe = create_recipe_with_ingredient(account, user, "Chicken Stir Fry", item)

      {:ok, view, _html} = live(conn, "/dashboard")

      html = render_click(view, "get_rescue_plan")

      assert html =~ "Rescue Recipes"
      assert html =~ "Chicken Stir Fry"
      assert html =~ "Add to Today"
    end

    test "Add to Today creates a meal plan", %{
      conn: conn,
      account: account,
      user: user
    } do
      item = create_expiring_item(account, user, "Spinach", 1)
      recipe = create_recipe_with_ingredient(account, user, "Spinach Salad", item)

      {:ok, view, _html} = live(conn, "/dashboard")

      # Load suggestions first
      render_click(view, "get_rescue_plan")

      # Click add to plan
      html =
        render_click(view, "add_rescue_to_plan", %{
          "recipe-id" => recipe.id
        })

      assert html =~ "Added to today&#39;s meal plan!"
    end
  end

  describe "Meal Planner Waste Watch Banner" do
    test "shows waste watch banner when items are expiring", %{
      conn: conn,
      account: account,
      user: user
    } do
      _item = create_expiring_item(account, user, "Tomatoes", 3)

      {:ok, _view, html} = live(conn, "/meal-planner")

      assert html =~ "items expiring this week"
      assert html =~ "Rescue Recipes"
      assert html =~ "Cook With These"
    end

    test "does not show banner when no items expiring", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/meal-planner")

      refute html =~ "items expiring this week"
    end

    test "dismiss button hides the banner", %{
      conn: conn,
      account: account,
      user: user
    } do
      _item = create_expiring_item(account, user, "Lettuce", 2)

      {:ok, view, _html} = live(conn, "/meal-planner")

      html = render_click(view, "dismiss_waste_watch")

      refute html =~ "items expiring this week"
    end

    test "Rescue Recipes button loads inline suggestions", %{
      conn: conn,
      account: account,
      user: user
    } do
      item = create_expiring_item(account, user, "Beef", 2)
      _recipe = create_recipe_with_ingredient(account, user, "Beef Stew", item)

      {:ok, view, _html} = live(conn, "/meal-planner")

      html = render_click(view, "waste_watch_suggestions")

      assert html =~ "Beef Stew"
    end
  end

  describe "Cook With These Modal" do
    test "opens modal with available inventory items", %{
      conn: conn,
      account: account,
      user: user
    } do
      # Create inventory items (no need to be expiring)
      item1 = create_grocery_item(account, user, %{name: "Rice"})
      create_inventory_entry(account, user, item1, %{quantity: Decimal.new("2")})

      item2 = create_grocery_item(account, user, %{name: "Beans"})
      create_inventory_entry(account, user, item2, %{quantity: Decimal.new("1")})

      {:ok, view, _html} = live(conn, "/meal-planner")

      html = render_click(view, "open_cook_with_modal")

      assert html =~ "Cook With These"
      assert html =~ "Rice"
      assert html =~ "Beans"
      assert html =~ "Find Recipes"
    end

    test "selecting ingredients and finding recipes returns results", %{
      conn: conn,
      account: account,
      user: user
    } do
      item = create_grocery_item(account, user, %{name: "Chicken"})
      create_inventory_entry(account, user, item, %{quantity: Decimal.new("1")})

      _recipe = create_recipe_with_ingredient(account, user, "Grilled Chicken", item)

      {:ok, view, _html} = live(conn, "/meal-planner")

      # Open modal
      render_click(view, "open_cook_with_modal")

      # Select ingredient
      render_click(view, "toggle_cook_with_ingredient", %{"id" => item.id})

      # Find recipes
      html = render_click(view, "find_cook_with_recipes")

      assert html =~ "Grilled Chicken"
      assert html =~ "Match:"
    end

    test "close button closes the modal", %{conn: conn, account: account, user: user} do
      item = create_grocery_item(account, user, %{name: "Pasta"})
      create_inventory_entry(account, user, item, %{quantity: Decimal.new("1")})

      {:ok, view, _html} = live(conn, "/meal-planner")

      render_click(view, "open_cook_with_modal")
      html = render_click(view, "close_cook_with_modal")

      refute html =~ "Cook With These"
    end

    test "add to plan from Cook With These creates meal plan", %{
      conn: conn,
      account: account,
      user: user
    } do
      item = create_grocery_item(account, user, %{name: "Salmon"})
      create_inventory_entry(account, user, item, %{quantity: Decimal.new("1")})

      recipe = create_recipe_with_ingredient(account, user, "Baked Salmon", item)

      {:ok, view, _html} = live(conn, "/meal-planner")

      render_click(view, "open_cook_with_modal")
      render_click(view, "toggle_cook_with_ingredient", %{"id" => item.id})
      render_click(view, "find_cook_with_recipes")

      html = render_click(view, "cook_with_add_to_plan", %{"recipe-id" => recipe.id})

      assert html =~ "Recipe added to today&#39;s plan!"
    end
  end
end
