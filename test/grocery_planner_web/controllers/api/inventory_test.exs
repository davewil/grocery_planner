defmodule GroceryPlannerWeb.Api.InventoryTest do
  use GroceryPlannerWeb.ConnCase, async: true
  import GroceryPlanner.InventoryTestHelpers

  setup do
    {account, user} = create_account_and_user()
    token = Phoenix.Token.sign(GroceryPlannerWeb.Endpoint, "user auth", user.id)
    %{account: account, user: user, token: token}
  end

  describe "GET /api/json/grocery_items" do
    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, "/api/json/grocery_items")
      assert json_response(conn, 401)
    end

    test "returns empty list with token", %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/grocery_items")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns items created by user", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      item = create_grocery_item(account, user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/grocery_items")

      assert %{"data" => [data]} = json_response(conn, 200)
      assert data["id"] == item.id
      assert data["attributes"]["name"] == item.name
    end
  end

  describe "POST /api/json/grocery_items" do
    test "creates a new grocery item", %{conn: conn, token: token, account: account} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/grocery_items", %{
          "data" => %{
            "type" => "grocery_item",
            "attributes" => %{
              "name" => "New Item",
              "account_id" => account.id
            }
          }
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["attributes"]["name"] == "New Item"
    end
  end
end
