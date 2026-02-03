defmodule GroceryPlannerWeb.Api.MealPlanTemplateEntryTest do
  @moduledoc """
  Behavioral tests for the MealPlanTemplateEntry JSON:API endpoints.
  Tests the nested resource pattern: /meal_plans/templates/:template_id/entries
  """
  use GroceryPlannerWeb.ConnCase, async: true
  import GroceryPlanner.MealPlanningTestHelpers

  setup do
    {account, user} = create_account_and_user()
    token = Phoenix.Token.sign(GroceryPlannerWeb.Endpoint, "user auth", user.id)
    template = create_meal_plan_template(account, user)
    recipe = create_recipe(account, user)
    %{account: account, user: user, token: token, template: template, recipe: recipe}
  end

  describe "GET /api/json/meal_plan_templates/:template_id/entries" do
    test "returns 401 without authentication token", %{conn: conn, template: template} do
      conn = get(conn, "/api/json/meal_plan_templates/#{template.id}/entries")
      assert json_response(conn, 401)
    end

    test "returns empty list when template has no entries", %{
      conn: conn,
      token: token,
      template: template
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/meal_plan_templates/#{template.id}/entries")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns entries belonging to the template", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      template: template,
      recipe: recipe
    } do
      entry =
        create_meal_plan_template_entry(account, user, template, recipe, %{
          day_of_week: 1,
          meal_type: :lunch
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/meal_plan_templates/#{template.id}/entries")

      assert %{"data" => [data]} = json_response(conn, 200)
      assert data["id"] == entry.id
      assert data["type"] == "meal_plan_template_entry"
      assert data["attributes"]["day_of_week"] == 1
      assert data["attributes"]["meal_type"] == "lunch"
    end

    test "returns empty list when accessing another account's template entries (tenant isolation)",
         %{
           conn: conn,
           token: token
         } do
      {other_account, other_user} = create_account_and_user()
      other_template = create_meal_plan_template(other_account, other_user)
      other_recipe = create_recipe(other_account, other_user)

      _other_entry =
        create_meal_plan_template_entry(other_account, other_user, other_template, other_recipe)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/meal_plan_templates/#{other_template.id}/entries")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/json/meal_plan_templates/:template_id/entries/:id" do
    test "returns a specific entry", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      template: template,
      recipe: recipe
    } do
      entry =
        create_meal_plan_template_entry(account, user, template, recipe, %{day_of_week: 3})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/meal_plan_templates/#{template.id}/entries/#{entry.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == entry.id
      assert data["attributes"]["day_of_week"] == 3
    end
  end

  describe "POST /api/json/meal_plan_templates/:template_id/entries" do
    test "creates a new entry in the template", %{
      conn: conn,
      token: token,
      template: template,
      recipe: recipe
    } do
      payload = %{
        "data" => %{
          "type" => "meal_plan_template_entry",
          "attributes" => %{
            "recipe_id" => recipe.id,
            "day_of_week" => 2,
            "meal_type" => "breakfast",
            "servings" => 2
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/meal_plan_templates/#{template.id}/entries", payload)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["type"] == "meal_plan_template_entry"
      assert data["attributes"]["day_of_week"] == 2
      assert data["attributes"]["meal_type"] == "breakfast"
      assert data["attributes"]["servings"] == 2
    end

    test "returns validation error when recipe_id is missing", %{
      conn: conn,
      token: token,
      template: template
    } do
      payload = %{
        "data" => %{
          "type" => "meal_plan_template_entry",
          "attributes" => %{
            "day_of_week" => 0,
            "meal_type" => "dinner"
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/meal_plan_templates/#{template.id}/entries", payload)

      assert %{"errors" => errors} = json_response(conn, 400)
      assert length(errors) > 0
    end

    test "returns validation error for invalid day_of_week", %{
      conn: conn,
      token: token,
      template: template,
      recipe: recipe
    } do
      payload = %{
        "data" => %{
          "type" => "meal_plan_template_entry",
          "attributes" => %{
            "recipe_id" => recipe.id,
            "day_of_week" => 7,
            "meal_type" => "dinner"
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/meal_plan_templates/#{template.id}/entries", payload)

      assert %{"errors" => _errors} = json_response(conn, 400)
    end
  end

  describe "PATCH /api/json/meal_plan_templates/:template_id/entries/:id" do
    test "updates an existing entry", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      template: template,
      recipe: recipe
    } do
      entry = create_meal_plan_template_entry(account, user, template, recipe)

      payload = %{
        "data" => %{
          "type" => "meal_plan_template_entry",
          "id" => entry.id,
          "attributes" => %{
            "day_of_week" => 5,
            "meal_type" => "snack",
            "servings" => 1
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/meal_plan_templates/#{template.id}/entries/#{entry.id}", payload)

      assert %{"data" => data} = json_response(conn, 200)
      assert data["attributes"]["day_of_week"] == 5
      assert data["attributes"]["meal_type"] == "snack"
      assert data["attributes"]["servings"] == 1
    end
  end

  describe "DELETE /api/json/meal_plan_templates/:template_id/entries/:id" do
    test "deletes an entry from the template", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      template: template,
      recipe: recipe
    } do
      entry = create_meal_plan_template_entry(account, user, template, recipe)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/json/meal_plan_templates/#{template.id}/entries/#{entry.id}")

      assert %{"data" => _} = json_response(conn, 200)

      # Verify entry is deleted
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/meal_plan_templates/#{template.id}/entries")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns error when deleting another account's entry (policy denies)", %{
      conn: conn,
      token: token
    } do
      {other_account, other_user} = create_account_and_user()
      other_template = create_meal_plan_template(other_account, other_user)
      other_recipe = create_recipe(other_account, other_user)

      other_entry =
        create_meal_plan_template_entry(other_account, other_user, other_template, other_recipe)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/json/meal_plan_templates/#{other_template.id}/entries/#{other_entry.id}")

      assert conn.status in [403, 404]
    end
  end
end
