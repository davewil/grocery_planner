defmodule GroceryPlannerWeb.Api.RecipeIngredientTest do
  @moduledoc """
  Behavioral tests for the RecipeIngredient JSON:API endpoints.
  Tests the nested resource pattern: /recipes/:recipe_id/ingredients
  """
  use GroceryPlannerWeb.ConnCase, async: true
  import GroceryPlanner.RecipesTestHelpers

  setup do
    {account, user} = create_account_and_user()
    token = Phoenix.Token.sign(GroceryPlannerWeb.Endpoint, "user auth", user.id)
    recipe = create_recipe(account, user)
    grocery_item = create_grocery_item(account, user)
    %{account: account, user: user, token: token, recipe: recipe, grocery_item: grocery_item}
  end

  describe "GET /api/json/recipes/:recipe_id/ingredients" do
    test "returns 401 without authentication token", %{conn: conn, recipe: recipe} do
      conn = get(conn, "/api/json/recipes/#{recipe.id}/ingredients")
      assert json_response(conn, 401)
    end

    test "returns empty list when recipe has no ingredients", %{
      conn: conn,
      token: token,
      recipe: recipe
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/recipes/#{recipe.id}/ingredients")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns ingredients belonging to the recipe", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      recipe: recipe,
      grocery_item: grocery_item
    } do
      ingredient =
        create_recipe_ingredient(account, user, recipe, grocery_item, %{
          quantity: Decimal.new("2")
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/recipes/#{recipe.id}/ingredients")

      assert %{"data" => [data]} = json_response(conn, 200)
      assert data["id"] == ingredient.id
      assert data["type"] == "recipe_ingredient"
      assert data["attributes"]["quantity"] == "2"
    end

    test "returns empty list when accessing another account's recipe (tenant isolation)", %{
      conn: conn,
      token: token
    } do
      {other_account, other_user} = create_account_and_user()
      other_recipe = create_recipe(other_account, other_user)
      other_item = create_grocery_item(other_account, other_user)

      _other_ingredient =
        create_recipe_ingredient(other_account, other_user, other_recipe, other_item)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/recipes/#{other_recipe.id}/ingredients")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "POST /api/json/recipes/:recipe_id/ingredients" do
    test "creates a new ingredient in the recipe", %{
      conn: conn,
      token: token,
      recipe: recipe,
      grocery_item: grocery_item
    } do
      payload = %{
        "data" => %{
          "type" => "recipe_ingredient",
          "attributes" => %{
            "grocery_item_id" => grocery_item.id,
            "quantity" => "3",
            "unit" => "tablespoons",
            "is_optional" => true
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/recipes/#{recipe.id}/ingredients", payload)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["type"] == "recipe_ingredient"
      assert data["attributes"]["quantity"] == "3"
      assert data["attributes"]["unit"] == "tablespoons"
      assert data["attributes"]["is_optional"] == true
    end

    test "returns validation error when grocery_item_id is missing", %{
      conn: conn,
      token: token,
      recipe: recipe
    } do
      payload = %{
        "data" => %{
          "type" => "recipe_ingredient",
          "attributes" => %{
            "quantity" => "1",
            "unit" => "cup"
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/recipes/#{recipe.id}/ingredients", payload)

      assert %{"errors" => errors} = json_response(conn, 400)
      assert length(errors) > 0
    end
  end

  describe "PATCH /api/json/recipes/:recipe_id/ingredients/:id" do
    test "updates an existing ingredient", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      recipe: recipe,
      grocery_item: grocery_item
    } do
      ingredient = create_recipe_ingredient(account, user, recipe, grocery_item)

      payload = %{
        "data" => %{
          "type" => "recipe_ingredient",
          "id" => ingredient.id,
          "attributes" => %{
            "quantity" => "5",
            "unit" => "pounds"
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/recipes/#{recipe.id}/ingredients/#{ingredient.id}", payload)

      assert %{"data" => data} = json_response(conn, 200)
      assert data["attributes"]["quantity"] == "5"
      assert data["attributes"]["unit"] == "pounds"
    end
  end

  describe "DELETE /api/json/recipes/:recipe_id/ingredients/:id" do
    test "deletes an ingredient from the recipe", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      recipe: recipe,
      grocery_item: grocery_item
    } do
      ingredient = create_recipe_ingredient(account, user, recipe, grocery_item)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/json/recipes/#{recipe.id}/ingredients/#{ingredient.id}")

      assert %{"data" => _} = json_response(conn, 200)

      # Verify ingredient is deleted
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/recipes/#{recipe.id}/ingredients")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns error when deleting another account's ingredient (policy denies)", %{
      conn: conn,
      token: token
    } do
      {other_account, other_user} = create_account_and_user()
      other_recipe = create_recipe(other_account, other_user)
      other_item = create_grocery_item(other_account, other_user)

      other_ingredient =
        create_recipe_ingredient(other_account, other_user, other_recipe, other_item)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/json/recipes/#{other_recipe.id}/ingredients/#{other_ingredient.id}")

      assert conn.status in [403, 404]
    end
  end
end
