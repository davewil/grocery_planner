defmodule GroceryPlannerWeb.Api.MealPlanTemplateTest do
  @moduledoc """
  Behavioral tests for the MealPlanTemplate JSON:API endpoints.
  Tests the top-level resource pattern: /meal_plans/templates
  """
  use GroceryPlannerWeb.ConnCase, async: true
  import GroceryPlanner.MealPlanningTestHelpers

  setup do
    {account, user} = create_account_and_user()
    token = Phoenix.Token.sign(GroceryPlannerWeb.Endpoint, "user auth", user.id)
    %{account: account, user: user, token: token}
  end

  describe "GET /api/json/meal_plan_templates" do
    test "returns 401 without authentication token", %{conn: conn} do
      conn = get(conn, "/api/json/meal_plan_templates")
      assert json_response(conn, 401)
    end

    test "returns empty list when no templates exist", %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/meal_plan_templates")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns templates belonging to the account", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      template = create_meal_plan_template(account, user, %{name: "Weekly Plan"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/meal_plan_templates")

      assert %{"data" => [data]} = json_response(conn, 200)
      assert data["id"] == template.id
      assert data["type"] == "meal_plan_template"
      assert data["attributes"]["name"] == "Weekly Plan"
      assert data["attributes"]["is_active"] == false
    end

    test "returns empty list when accessing another account's templates (tenant isolation)", %{
      conn: conn,
      token: token
    } do
      {other_account, other_user} = create_account_and_user()
      _other_template = create_meal_plan_template(other_account, other_user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/meal_plan_templates")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/json/meal_plan_templates/:id" do
    test "returns a specific template", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      template = create_meal_plan_template(account, user, %{name: "My Template"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/meal_plan_templates/#{template.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == template.id
      assert data["attributes"]["name"] == "My Template"
    end

    test "returns 404 for non-existent template", %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/meal_plan_templates/#{Ecto.UUID.generate()}")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/json/meal_plan_templates" do
    test "creates a new template", %{conn: conn, token: token, account: account} do
      payload = %{
        "data" => %{
          "type" => "meal_plan_template",
          "attributes" => %{
            "name" => "New Weekly Template",
            "is_active" => true,
            "account_id" => account.id
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/meal_plan_templates", payload)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["type"] == "meal_plan_template"
      assert data["attributes"]["name"] == "New Weekly Template"
      assert data["attributes"]["is_active"] == true
    end

    test "returns validation error when name is missing", %{
      conn: conn,
      token: token,
      account: account
    } do
      payload = %{
        "data" => %{
          "type" => "meal_plan_template",
          "attributes" => %{
            "account_id" => account.id
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/meal_plan_templates", payload)

      assert %{"errors" => errors} = json_response(conn, 400)
      assert length(errors) > 0
    end
  end

  describe "PATCH /api/json/meal_plan_templates/:id" do
    test "updates an existing template", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      template = create_meal_plan_template(account, user, %{name: "Old Name"})

      payload = %{
        "data" => %{
          "type" => "meal_plan_template",
          "id" => template.id,
          "attributes" => %{
            "name" => "Updated Name"
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/meal_plan_templates/#{template.id}", payload)

      assert %{"data" => data} = json_response(conn, 200)
      assert data["attributes"]["name"] == "Updated Name"
    end
  end

  describe "PATCH /api/json/meal_plan_templates/:id/activate" do
    test "activates a template", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      template = create_meal_plan_template(account, user, %{is_active: false})

      payload = %{
        "data" => %{
          "type" => "meal_plan_template",
          "id" => template.id
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/meal_plan_templates/#{template.id}/activate", payload)

      assert %{"data" => data} = json_response(conn, 200)
      assert data["attributes"]["is_active"] == true
    end
  end

  describe "PATCH /api/json/meal_plan_templates/:id/deactivate" do
    test "deactivates a template", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      template = create_meal_plan_template(account, user, %{is_active: true})

      payload = %{
        "data" => %{
          "type" => "meal_plan_template",
          "id" => template.id
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/meal_plan_templates/#{template.id}/deactivate", payload)

      assert %{"data" => data} = json_response(conn, 200)
      assert data["attributes"]["is_active"] == false
    end
  end

  describe "DELETE /api/json/meal_plan_templates/:id" do
    test "deletes a template", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      template = create_meal_plan_template(account, user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/json/meal_plan_templates/#{template.id}")

      assert %{"data" => _} = json_response(conn, 200)

      # Verify template is deleted
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/meal_plan_templates")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns error when deleting another account's template (policy denies)", %{
      conn: conn,
      token: token
    } do
      {other_account, other_user} = create_account_and_user()
      other_template = create_meal_plan_template(other_account, other_user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/json/meal_plan_templates/#{other_template.id}")

      assert conn.status in [403, 404]
    end
  end
end
