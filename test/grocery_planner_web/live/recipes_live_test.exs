defmodule GroceryPlannerWeb.RecipesLiveTest do
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

  defp create_recipe(account, _user, attrs) do
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

  describe "Recipes List" do
    test "renders recipes list", %{conn: conn, account: account, user: user} do
      _recipe = create_recipe(account, user, %{name: "Spaghetti Bolognese"})

      {:ok, _view, html} = live(conn, "/recipes")

      assert html =~ "Recipes"
      assert html =~ "Spaghetti Bolognese"
      assert html =~ "New Recipe"
    end

    test "filters recipes by search", %{conn: conn, account: account, user: user} do
      create_recipe(account, user, %{name: "Spaghetti Bolognese"})
      create_recipe(account, user, %{name: "Chicken Curry"})

      {:ok, view, _html} = live(conn, "/recipes")

      assert render(view) =~ "Spaghetti Bolognese"
      assert render(view) =~ "Chicken Curry"

      view
      |> element("form[phx-change='search']")
      |> render_change(%{"query" => "Curry"})

      assert render(view) =~ "Chicken Curry"
      refute render(view) =~ "Spaghetti Bolognese"
    end

    test "filters recipes by difficulty", %{conn: conn, account: account, user: user} do
      create_recipe(account, user, %{name: "Easy Dish", difficulty: :easy})
      create_recipe(account, user, %{name: "Hard Dish", difficulty: :hard})

      {:ok, view, _html} = live(conn, "/recipes")

      assert render(view) =~ "Easy Dish"
      assert render(view) =~ "Hard Dish"

      view
      |> element("form[phx-change='filter_difficulty']")
      |> render_change(%{"value" => "easy"})

      assert render(view) =~ "Easy Dish"
      refute render(view) =~ "Hard Dish"

      # Test invalid difficulty
      view
      |> element("form[phx-change='filter_difficulty']")
      |> render_change(%{"value" => "invalid"})

      assert render(view) =~ "Easy Dish"
      assert render(view) =~ "Hard Dish"
    end

    test "toggles favorites and filters by favorite", %{conn: conn, account: account, user: user} do
      recipe = create_recipe(account, user, %{name: "My Favorite", is_favorite: false})
      create_recipe(account, user, %{name: "Not Favorite", is_favorite: false})

      {:ok, view, _html} = live(conn, "/recipes")

      assert render(view) =~ "My Favorite"
      assert render(view) =~ "Not Favorite"

      # Toggle favorite
      view
      |> element("button[phx-click='toggle_favorite'][phx-value-id='#{recipe.id}']")
      |> render_click()

      # Filter by favorites
      view
      |> element("button[phx-click='toggle_favorites']")
      |> render_click()

      assert render(view) =~ "My Favorite"
      refute render(view) =~ "Not Favorite"
    end

    test "navigates to new recipe page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/recipes")

      view
      |> element("button[phx-click='new_recipe']")
      |> render_click()

      {path, _flash} = assert_redirect(view)
      assert path == "/recipes/new"
    end

    test "navigates to recipe details", %{conn: conn, account: account, user: user} do
      recipe = create_recipe(account, user, %{name: "View Me"})
      {:ok, view, _html} = live(conn, "/recipes")

      view
      |> element("div[phx-click='view_recipe'][phx-value-id='#{recipe.id}']")
      |> render_click()

      {path, _flash} = assert_redirect(view)
      assert path == "/recipes/#{recipe.id}"
    end

    # test "handles error when toggling favorite fails", %{conn: conn} do
    #   {:ok, view, _html} = live(conn, "/recipes")

    #   # Try to toggle favorite for a non-existent ID (valid UUID but not found)
    #   non_existent_id = Ash.UUID.generate()

    #   view
    #   |> element("button[phx-click='toggle_favorite'][phx-value-id='#{non_existent_id}']")
    #   |> render_click()

    #   assert render(view) =~ "Failed to update favorite status"
    # end
  end

  describe "Recipe Show" do
    test "renders recipe details", %{conn: conn, account: account, user: user} do
      recipe =
        create_recipe(account, user, %{
          name: "Spaghetti Bolognese",
          description: "Classic Italian dish",
          instructions: "Boil pasta. Cook sauce."
        })

      {:ok, _view, html} = live(conn, "/recipes/#{recipe.id}")

      assert html =~ "Spaghetti Bolognese"
      assert html =~ "Classic Italian dish"
      assert html =~ "Boil pasta. Cook sauce."
    end
  end

  describe "Recipe Form" do
    test "creates a new recipe", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/recipes/new")

      assert render(view) =~ "New Recipe"

      view
      |> form("#recipe-form", %{
        "recipe" => %{
          "name" => "Pancakes",
          "description" => "Fluffy pancakes",
          "instructions" => "Mix flour, milk, eggs.",
          "prep_time_minutes" => "5",
          "cook_time_minutes" => "10",
          "servings" => "2",
          "difficulty" => "easy"
        }
      })
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      assert path =~ "/recipes/"
    end

    test "edits an existing recipe", %{conn: conn, account: account, user: user} do
      recipe = create_recipe(account, user, %{name: "Old Name"})

      {:ok, view, _html} = live(conn, "/recipes/#{recipe.id}/edit")

      assert render(view) =~ "Edit Recipe"
      assert render(view) =~ "Old Name"

      view
      |> form("#recipe-form", %{
        "recipe" => %{
          "name" => "New Name",
          # Ensure required field is present if needed
          "servings" => "4"
        }
      })
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      assert path == "/recipes/#{recipe.id}"
    end
  end
end
