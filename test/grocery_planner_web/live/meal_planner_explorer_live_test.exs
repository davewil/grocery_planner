defmodule GroceryPlannerWeb.MealPlannerExplorerLiveTest do
  use GroceryPlannerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import GroceryPlanner.MealPlanningTestHelpers

  setup do
    account = create_account()
    user = create_user(account)

    {:ok, user} = GroceryPlanner.Accounts.User.update(user, %{meal_planner_layout: "explorer"})

    conn =
      build_conn()
      |> init_test_session(%{
        user_id: user.id,
        account_id: account.id
      })

    %{conn: conn, account: account, user: user}
  end

  test "renders explorer timeline and recipe feed", %{conn: conn, account: account, user: user} do
    recipe = create_recipe(account, user, %{name: "Explorer Test Recipe", is_favorite: true})

    {:ok, view, html} = live(conn, "/meal-planner")

    assert html =~ "Layout"
    assert html =~ "Explorer"

    assert has_element?(view, "#explorer-timeline")
    assert has_element?(view, "#explorer-feed")
    assert has_element?(view, "#explorer-recipe-search")

    assert has_element?(view, "#explorer-favorites")
    assert has_element?(view, "#explorer-favorite-add-#{recipe.id}")
  end

  test "quick add opens slot picker", %{conn: conn, account: account, user: user} do
    recipe = create_recipe(account, user, %{name: "Quick Add Recipe"})

    {:ok, view, _html} = live(conn, "/meal-planner")

    view
    |> element("#explorer-quick-add-#{recipe.id}")
    |> render_click()

    assert has_element?(view, "#explorer-slot-picker")
    assert has_element?(view, "#explorer-confirm-add")
  end
end
