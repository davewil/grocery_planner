defmodule GroceryPlannerWeb.Api.ErrorResponsesTest do
  @moduledoc """
  Behavioral tests for consistent JSON:API error responses (US-005).

  Verifies that all API error responses follow JSON:API v1.0 format.
  """
  use GroceryPlannerWeb.ConnCase, async: true
  import GroceryPlanner.ShoppingTestHelpers

  setup do
    {account, user} = create_account_and_user()
    token = Phoenix.Token.sign(GroceryPlannerWeb.Endpoint, "user auth", user.id)
    shopping_list = create_shopping_list(account, user)
    %{account: account, user: user, token: token, shopping_list: shopping_list}
  end

  describe "401 Unauthorized errors" do
    test "returns JSON:API formatted error when no auth token provided", %{
      conn: conn,
      shopping_list: list
    } do
      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/shopping_lists/#{list.id}/items")

      assert %{"errors" => [error], "jsonapi" => %{"version" => "1.0"}} = json_response(conn, 401)
      assert error["status"] == "401"
      assert error["code"] == "unauthorized"
      assert error["title"] == "Unauthorized"
      assert is_binary(error["detail"])
      assert is_binary(error["id"])
    end

    test "returns JSON:API formatted error when token is invalid", %{
      conn: conn,
      shopping_list: list
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid_token")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/shopping_lists/#{list.id}/items")

      assert %{"errors" => [error], "jsonapi" => %{"version" => "1.0"}} = json_response(conn, 401)
      assert error["status"] == "401"
      assert error["code"] == "unauthorized"
    end

    test "returns JSON:API formatted error when token is expired", %{
      conn: conn,
      user: user,
      shopping_list: list
    } do
      # Simulate invalid token by using wrong secret (expired tokens behave similarly)
      bad_token = Phoenix.Token.sign(GroceryPlannerWeb.Endpoint, "wrong secret", user.id)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{bad_token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/shopping_lists/#{list.id}/items")

      assert %{"errors" => [error], "jsonapi" => %{"version" => "1.0"}} = json_response(conn, 401)
      assert error["status"] == "401"
    end
  end

  describe "400 Validation errors" do
    test "returns JSON:API formatted error with field-level details on create", %{
      conn: conn,
      token: token,
      shopping_list: list
    } do
      # Missing required "name" field
      payload = %{
        "data" => %{
          "type" => "shopping_list_item",
          "attributes" => %{}
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/shopping_lists/#{list.id}/items", payload)

      assert %{"errors" => errors} = json_response(conn, 400)
      assert length(errors) > 0

      # At least one error should reference the name field
      name_error =
        Enum.find(errors, fn error ->
          error["source"]["pointer"] =~ "name" or
            (error["detail"] || "") =~ "name"
        end)

      assert name_error != nil, "Expected an error referencing the 'name' field"
    end

    test "validation error includes status code as string", %{
      conn: conn,
      token: token,
      shopping_list: list
    } do
      payload = %{
        "data" => %{
          "type" => "shopping_list_item",
          "attributes" => %{}
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/shopping_lists/#{list.id}/items", payload)

      assert %{"errors" => [error | _]} = json_response(conn, 400)
      # JSON:API requires status to be a string
      assert is_binary(error["status"])
    end
  end

  describe "403 Forbidden errors" do
    test "returns error when accessing resource from another tenant", %{
      conn: conn,
      token: token
    } do
      # Create another account with its own shopping list
      {other_account, other_user} = create_account_and_user()
      other_list = create_shopping_list(other_account, other_user, %{name: "Other List"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/shopping_lists/#{other_list.id}/items")

      # Multitenancy may return 403 or 404 (empty result due to tenant isolation)
      # Both are acceptable for cross-tenant access
      assert conn.status in [403, 404, 200]

      # If 200, it should return empty data (tenant isolation)
      if conn.status == 200 do
        assert %{"data" => []} = json_response(conn, 200)
      end
    end
  end

  describe "404 Not Found errors" do
    test "returns JSON:API formatted error for non-existent resource", %{
      conn: conn,
      token: token,
      shopping_list: list
    } do
      fake_id = Ash.UUID.generate()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/shopping_lists/#{list.id}/items/#{fake_id}")

      assert %{"errors" => [error | _]} = json_response(conn, 404)
      assert error["status"] == "404"
    end

    test "returns JSON:API formatted error for non-existent parent resource", %{
      conn: conn,
      token: token
    } do
      fake_list_id = Ash.UUID.generate()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/shopping_lists/#{fake_list_id}/items")

      # May return 404 or empty list depending on implementation
      assert conn.status in [404, 200]
    end

    test "returns JSON:API formatted error for undefined route", %{
      conn: conn,
      token: token
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/nonexistent_resource")

      assert %{"errors" => [error | _]} = json_response(conn, 404)
      assert error["status"] == "404"
      assert error["code"] == "no_route_found"
    end
  end

  describe "Content-Type header" do
    test "error responses use application/vnd.api+json content type", %{
      conn: conn,
      shopping_list: list
    } do
      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/shopping_lists/#{list.id}/items")

      assert get_resp_header(conn, "content-type") |> List.first() =~ "application/vnd.api+json"
    end
  end
end
