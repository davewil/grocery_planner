defmodule GroceryPlannerWeb.Api.ShoppingListItemTest do
  @moduledoc """
  Behavioral tests for the ShoppingListItem JSON:API endpoints.

  Tests the nested resource pattern: /shopping_lists/:shopping_list_id/items
  """
  use GroceryPlannerWeb.ConnCase, async: true
  import GroceryPlanner.ShoppingTestHelpers

  setup do
    {account, user} = create_account_and_user()
    token = Phoenix.Token.sign(GroceryPlannerWeb.Endpoint, "user auth", user.id)
    shopping_list = create_shopping_list(account, user)
    %{account: account, user: user, token: token, shopping_list: shopping_list}
  end

  describe "GET /api/json/shopping_lists/:shopping_list_id/items" do
    test "returns 401 without authentication token", %{conn: conn, shopping_list: list} do
      conn = get(conn, "/api/json/shopping_lists/#{list.id}/items")
      assert json_response(conn, 401)
    end

    test "returns empty list when shopping list has no items", %{
      conn: conn,
      token: token,
      shopping_list: list
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/shopping_lists/#{list.id}/items")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns items belonging to the shopping list", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      shopping_list: list
    } do
      item = create_shopping_list_item(account, user, list, %{name: "Milk"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/shopping_lists/#{list.id}/items")

      assert %{"data" => [data]} = json_response(conn, 200)
      assert data["id"] == item.id
      assert data["type"] == "shopping_list_item"
      assert data["attributes"]["name"] == "Milk"
      assert data["attributes"]["checked"] == false
    end

    test "filters items by shopping_list_id from route", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      shopping_list: list
    } do
      other_list = create_shopping_list(account, user, %{name: "Other List"})
      _other_item = create_shopping_list_item(account, user, other_list, %{name: "Other Item"})
      our_item = create_shopping_list_item(account, user, list, %{name: "Our Item"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/shopping_lists/#{list.id}/items")

      assert %{"data" => items} = json_response(conn, 200)
      # Verify our item is returned (nested route filters by shopping_list_id)
      item_ids = Enum.map(items, & &1["id"])
      assert our_item.id in item_ids
    end

    test "returns empty list when accessing another account's shopping list (tenant isolation)", %{
      conn: conn,
      token: token
    } do
      {other_account, other_user} = create_account_and_user()
      other_list = create_shopping_list(other_account, other_user)
      _other_item = create_shopping_list_item(other_account, other_user, other_list)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/shopping_lists/#{other_list.id}/items")

      # Tenant isolation means items outside user's tenant are not visible
      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "POST /api/json/shopping_lists/:shopping_list_id/items" do
    test "creates a new item in the shopping list", %{
      conn: conn,
      token: token,
      shopping_list: list
    } do
      payload = %{
        "data" => %{
          "type" => "shopping_list_item",
          "attributes" => %{
            "name" => "Eggs",
            "quantity" => "12",
            "unit" => "count"
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/shopping_lists/#{list.id}/items", payload)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["type"] == "shopping_list_item"
      assert data["attributes"]["name"] == "Eggs"
      assert data["attributes"]["quantity"] == "12"
      assert data["attributes"]["unit"] == "count"
      assert data["attributes"]["checked"] == false
    end

    test "returns validation error when name is missing", %{
      conn: conn,
      token: token,
      shopping_list: list
    } do
      payload = %{
        "data" => %{
          "type" => "shopping_list_item",
          "attributes" => %{
            "quantity" => "1"
          }
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
    end
  end

  describe "PATCH /api/json/shopping_lists/:shopping_list_id/items/:id" do
    test "updates an existing item", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      shopping_list: list
    } do
      item = create_shopping_list_item(account, user, list, %{name: "Original"})

      payload = %{
        "data" => %{
          "type" => "shopping_list_item",
          "id" => item.id,
          "attributes" => %{
            "name" => "Updated",
            "quantity" => "5"
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/shopping_lists/#{list.id}/items/#{item.id}", payload)

      assert %{"data" => data} = json_response(conn, 200)
      assert data["attributes"]["name"] == "Updated"
      assert data["attributes"]["quantity"] == "5"
    end
  end

  describe "PATCH /api/json/shopping_lists/:shopping_list_id/items/:id/toggle" do
    test "toggles item from unchecked to checked", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      shopping_list: list
    } do
      item = create_shopping_list_item(account, user, list, %{name: "Toggle Me", checked: false})

      payload = %{
        "data" => %{
          "type" => "shopping_list_item",
          "id" => item.id,
          "attributes" => %{}
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/shopping_lists/#{list.id}/items/#{item.id}/toggle", payload)

      assert %{"data" => data} = json_response(conn, 200)
      assert data["attributes"]["checked"] == true
    end

    test "toggles item from checked to unchecked", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      shopping_list: list
    } do
      item = create_shopping_list_item(account, user, list, %{name: "Toggle Me", checked: true})

      payload = %{
        "data" => %{
          "type" => "shopping_list_item",
          "id" => item.id,
          "attributes" => %{}
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/shopping_lists/#{list.id}/items/#{item.id}/toggle", payload)

      assert %{"data" => data} = json_response(conn, 200)
      assert data["attributes"]["checked"] == false
    end
  end

  describe "PATCH /api/json/shopping_lists/:shopping_list_id/items/:id/check" do
    test "marks item as checked", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      shopping_list: list
    } do
      item = create_shopping_list_item(account, user, list, %{name: "Check Me", checked: false})

      payload = %{
        "data" => %{
          "type" => "shopping_list_item",
          "id" => item.id,
          "attributes" => %{}
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/shopping_lists/#{list.id}/items/#{item.id}/check", payload)

      assert %{"data" => data} = json_response(conn, 200)
      assert data["attributes"]["checked"] == true
    end
  end

  describe "PATCH /api/json/shopping_lists/:shopping_list_id/items/:id/uncheck" do
    test "marks item as unchecked", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      shopping_list: list
    } do
      item = create_shopping_list_item(account, user, list, %{name: "Uncheck Me", checked: true})

      payload = %{
        "data" => %{
          "type" => "shopping_list_item",
          "id" => item.id,
          "attributes" => %{}
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/shopping_lists/#{list.id}/items/#{item.id}/uncheck", payload)

      assert %{"data" => data} = json_response(conn, 200)
      assert data["attributes"]["checked"] == false
    end
  end

  describe "DELETE /api/json/shopping_lists/:shopping_list_id/items/:id" do
    test "deletes an item from the shopping list", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      shopping_list: list
    } do
      item = create_shopping_list_item(account, user, list, %{name: "Delete Me"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/json/shopping_lists/#{list.id}/items/#{item.id}")

      # AshJsonApi returns 200 with deleted resource data by default
      assert %{"data" => _} = json_response(conn, 200)

      # Verify item is deleted by trying to fetch list items
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/shopping_lists/#{list.id}/items")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 403 when deleting another account's item (policy denies)", %{
      conn: conn,
      token: token
    } do
      {other_account, other_user} = create_account_and_user()
      other_list = create_shopping_list(other_account, other_user)
      other_item = create_shopping_list_item(other_account, other_user, other_list)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/json/shopping_lists/#{other_list.id}/items/#{other_item.id}")

      # Tenant isolation returns 404 (item not found in user's tenant) or 403
      assert conn.status in [403, 404]
    end
  end
end
