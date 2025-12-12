defmodule GroceryPlannerWeb.RecipeSearchLiveTest do
  use GroceryPlannerWeb.ConnCase
  import Phoenix.LiveViewTest
  import GroceryPlanner.InventoryTestHelpers
  alias GroceryPlanner.External.TheMealDB

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

  test "renders search page", %{conn: conn} do
    {:ok, view, html} = live(conn, "/recipes/search")

    assert html =~ "Search TheMealDB"
    assert html =~ "Search for recipes"
  end

  test "searches for recipes", %{conn: conn} do
    Req.Test.stub(TheMealDB, fn conn ->
      assert conn.request_path == "/api/json/v1/1/search.php"
      assert conn.query_params["s"] == "chicken"

      Req.Test.json(conn, %{
        "meals" => [
          %{
            "idMeal" => "52940",
            "strMeal" => "Brown Stew Chicken",
            "strCategory" => "Chicken",
            "strArea" => "Jamaican",
            "strInstructions" => "Instructions...",
            "strMealThumb" => "https://example.com/image.jpg",
            "strYoutube" => "",
            "strSource" => "",
            "strTags" => "Stew",
            "strIngredient1" => "",
            "strMeasure1" => ""
          },
          %{
            "idMeal" => "52795",
            "strMeal" => "Chicken Handi",
            "strCategory" => "Chicken",
            "strArea" => "Indian",
            "strInstructions" => "Instructions...",
            "strMealThumb" => "https://example.com/image2.jpg",
            "strYoutube" => "",
            "strSource" => "",
            "strTags" => nil,
            "strIngredient1" => "",
            "strMeasure1" => ""
          }
        ]
      })
    end)

    {:ok, view, _html} = live(conn, "/recipes/search")

    # Allow the LiveView process to use the test expectation
    Req.Test.allow(TheMealDB, self(), view.pid)

    view
    |> form("form[phx-submit='search']", %{"query" => "chicken"})
    |> render_submit()

    assert render(view) =~ "Brown Stew Chicken"
    assert render(view) =~ "Chicken Handi"
  end

  test "imports a recipe", %{conn: conn, account: account} do
    Req.Test.stub(TheMealDB, fn conn ->
      case conn.request_path do
        "/api/json/v1/1/search.php" ->
          Req.Test.json(conn, %{
            "meals" => [
              %{
                "idMeal" => "52940",
                "strMeal" => "Brown Stew Chicken",
                "strCategory" => "Chicken",
                "strArea" => "Jamaican",
                "strInstructions" => "Instructions...",
                "strMealThumb" => "https://example.com/image.jpg",
                "strYoutube" => "",
                "strSource" => "",
                "strTags" => "Stew",
                "strIngredient1" => "Chicken",
                "strMeasure1" => "1 whole",
                "strIngredient2" => "Tomato",
                "strMeasure2" => "2"
              }
            ]
          })

        "/api/json/v1/1/lookup.php" ->
          assert conn.query_params["i"] == "52940"

          Req.Test.json(conn, %{
            "meals" => [
              %{
                "idMeal" => "52940",
                "strMeal" => "Brown Stew Chicken",
                "strCategory" => "Chicken",
                "strArea" => "Jamaican",
                "strInstructions" => "Instructions...",
                "strMealThumb" => "https://example.com/image.jpg",
                "strYoutube" => "",
                "strSource" => "",
                "strTags" => "Stew",
                "strIngredient1" => "Chicken",
                "strMeasure1" => "1 whole",
                "strIngredient2" => "Tomato",
                "strMeasure2" => "2"
              }
            ]
          })
      end
    end)

    {:ok, view, _html} = live(conn, "/recipes/search")
    Req.Test.allow(TheMealDB, self(), view.pid)

    view
    |> form("form[phx-submit='search']", %{"query" => "chicken"})
    |> render_submit()

    # Wait for search results
    assert render(view) =~ "Brown Stew Chicken"

    # Click import on first result
    view
    |> element("button", "Import Recipe")
    |> render_click()

    {path, _flash} = assert_redirect(view)
    assert path =~ "/recipes/"

    # Verify recipe was created
    assert GroceryPlanner.Recipes.list_recipes!(authorize?: false, tenant: account.id) |> length() ==
             1
  end
end
