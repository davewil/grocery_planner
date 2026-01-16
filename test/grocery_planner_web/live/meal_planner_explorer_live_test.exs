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

    assert has_element?(view, "#explorer-feed") or has_element?(view, "#explorer-clear-filters") or
             has_element?(view, "#explorer-all-title")

    assert has_element?(view, "#explorer-recipe-search")

    assert has_element?(view, "#explorer-favorites")
    assert has_element?(view, "#explorer-favorite-add-#{recipe.id}")
  end

  test "clicking empty explorer slot opens recipe picker", %{
    conn: conn,
    account: account,
    user: user
  } do
    _recipe = create_recipe(account, user, %{name: "Slot Picker Recipe"})

    {:ok, view, _html} = live(conn, "/meal-planner")

    today = Date.utc_today()

    view
    |> element(
      ".hidden.lg\\:grid button[phx-click='explorer_open_recipe_picker'][phx-value-date='#{today}'][phx-value-meal_type='dinner']"
    )
    |> render_click()

    assert has_element?(view, "#meal-modal-backdrop")
    assert has_element?(view, "#add-meal-title")
    assert has_element?(view, "#add-meal-subtitle")
  end

  test "can favorite from explorer and it appears in favorites section", %{
    conn: conn,
    account: account,
    user: user
  } do
    recipe = create_recipe(account, user, %{name: "Not Favorite"})

    {:ok, view, _html} = live(conn, "/meal-planner")

    view
    |> element("button[phx-click='explorer_toggle_favorite'][phx-value-recipe_id='#{recipe.id}']")
    |> render_click()

    assert has_element?(view, "#explorer-favorites")
    assert has_element?(view, "#explorer-favorite-add-#{recipe.id}")
  end

  describe "recipe tags on cards" do
    test "displays cuisine tag on recipe cards", %{conn: conn, account: account, user: user} do
      _recipe =
        create_recipe(account, user, %{
          name: "Italian Pasta",
          cuisine: "Italian",
          is_favorite: true
        })

      {:ok, _view, html} = live(conn, "/meal-planner")

      assert html =~ "Italian"
    end

    test "displays dietary needs tags on recipe cards", %{
      conn: conn,
      account: account,
      user: user
    } do
      _recipe =
        create_recipe(account, user, %{
          name: "Vegan Bowl",
          dietary_needs: [:vegan, :gluten_free],
          is_favorite: true
        })

      {:ok, _view, html} = live(conn, "/meal-planner")

      assert html =~ "Vegan"
      assert html =~ "Gluten Free"
    end

    test "displays both cuisine and dietary tags together", %{
      conn: conn,
      account: account,
      user: user
    } do
      _recipe =
        create_recipe(account, user, %{
          name: "Thai Curry",
          cuisine: "Thai",
          dietary_needs: [:dairy_free, :nut_free],
          is_favorite: true
        })

      {:ok, _view, html} = live(conn, "/meal-planner")

      assert html =~ "Thai"
      assert html =~ "Dairy Free"
      assert html =~ "Nut Free"
    end

    test "shows +N indicator when more than 3 dietary needs", %{
      conn: conn,
      account: account,
      user: user
    } do
      _recipe =
        create_recipe(account, user, %{
          name: "Super Healthy",
          dietary_needs: [:vegan, :gluten_free, :dairy_free, :nut_free, :keto],
          is_favorite: true
        })

      {:ok, _view, html} = live(conn, "/meal-planner")

      # Should show first 3 + "+2" indicator
      assert html =~ "Vegan"
      assert html =~ "Gluten Free"
      assert html =~ "Dairy Free"
      assert html =~ "+2"
    end
  end
end
