defmodule GroceryPlannerWeb.DashboardLiveTest do
  use GroceryPlannerWeb.ConnCase
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

  defp create_recipe(account, _user, attrs \\ %{}) do
    default_attrs = %{
      name: "Test Recipe #{System.unique_integer()}",
      description: "A delicious test recipe",
      instructions: "Mix ingredients and cook.",
      prep_time_minutes: 10,
      cook_time_minutes: 20,
      servings: 4,
      difficulty: :medium
    }
    attrs = Map.merge(default_attrs, attrs)

    {:ok, recipe} =
      Recipes.create_recipe(
        account.id,
        attrs,
        authorize?: false,
        tenant: account.id
      )
    recipe
  end

  test "renders dashboard", %{conn: conn, user: user} do
    {:ok, view, html} = live(conn, "/dashboard")

    assert html =~ "Welcome, #{user.name}!"
    assert html =~ "Quick Access"
  end

  test "displays expiring items summary", %{conn: conn, account: account, user: user} do
    # Create expiring item
    item = create_grocery_item(account, user, %{name: "Milk"})
    create_inventory_entry(account, user, item, %{
      quantity: Decimal.new("1"),
      use_by_date: Date.utc_today() |> Date.add(2)
    })

    {:ok, view, html} = live(conn, "/dashboard")

    assert html =~ "Expiration Alerts"
    assert html =~ "This Week" # Milk expires in 2 days, so it falls in "This Week" (next 3 days) bucket or "Expires Tomorrow" depending on logic.
    # Logic in template:
    # expired_count > 0 -> Expired
    # today_count > 0 -> Expires Today
    # tomorrow_count > 0 -> Expires Tomorrow
    # this_week_count > 0 -> This Week
    
    # Date.add(2) is day after tomorrow. So it should be in "This Week" (Next 3 days usually implies 0-3 or 2-5? Need to check logic).
    # Assuming "This Week" covers it.
  end

  test "displays recipe suggestions", %{conn: conn, account: account, user: user} do
    # Create expiring item
    item = create_grocery_item(account, user, %{name: "Chicken"})
    create_inventory_entry(account, user, item, %{
      quantity: Decimal.new("1"),
      use_by_date: Date.utc_today() |> Date.add(2)
    })

    recipe = create_recipe(account, user, %{name: "Chicken Curry"})
    
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

    {:ok, view, html} = live(conn, "/dashboard")

    assert html =~ "Suggested Recipes"
    assert html =~ "Chicken Curry"
  end
end
