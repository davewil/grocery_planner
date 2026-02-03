defmodule GroceryPlannerWeb.Api.InventoryEntryTest do
  @moduledoc """
  Behavioral tests for the InventoryEntry JSON:API endpoints.

  Tests the nested resource pattern: /grocery_items/:grocery_item_id/inventory_entries
  """
  use GroceryPlannerWeb.ConnCase, async: true
  import GroceryPlanner.InventoryTestHelpers

  setup do
    {account, user} = create_account_and_user()
    token = Phoenix.Token.sign(GroceryPlannerWeb.Endpoint, "user auth", user.id)
    grocery_item = create_grocery_item(account, user, %{name: "Test Item"})
    %{account: account, user: user, token: token, grocery_item: grocery_item}
  end

  describe "GET /api/json/grocery_items/:grocery_item_id/inventory_entries" do
    test "returns 401 without authentication token", %{conn: conn, grocery_item: item} do
      conn = get(conn, "/api/json/grocery_items/#{item.id}/inventory_entries")
      assert json_response(conn, 401)
    end

    test "returns empty list when grocery item has no inventory entries", %{
      conn: conn,
      token: token,
      grocery_item: item
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/grocery_items/#{item.id}/inventory_entries")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns entries belonging to the grocery item", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      grocery_item: item
    } do
      entry = create_inventory_entry(account, user, item, %{quantity: Decimal.new("5")})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/grocery_items/#{item.id}/inventory_entries")

      assert %{"data" => [data]} = json_response(conn, 200)
      assert data["id"] == entry.id
      assert data["type"] == "inventory_entry"
      assert data["attributes"]["quantity"] == "5"
      assert data["attributes"]["status"] == "available"
    end

    test "filters entries by grocery_item_id from route", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      grocery_item: item
    } do
      other_item = create_grocery_item(account, user, %{name: "Other Item"})
      _other_entry = create_inventory_entry(account, user, other_item, %{quantity: Decimal.new("10")})
      our_entry = create_inventory_entry(account, user, item, %{quantity: Decimal.new("3")})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/grocery_items/#{item.id}/inventory_entries")

      assert %{"data" => entries} = json_response(conn, 200)
      # Verify our entry is returned (nested route filters by grocery_item_id)
      entry_ids = Enum.map(entries, & &1["id"])
      assert our_entry.id in entry_ids
      assert length(entries) == 1
    end

    test "supports filtering by status", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      grocery_item: item
    } do
      _available_entry = create_inventory_entry(account, user, item, %{quantity: Decimal.new("1"), status: :available})
      _expired_entry = create_inventory_entry(account, user, item, %{quantity: Decimal.new("2"), status: :expired})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/grocery_items/#{item.id}/inventory_entries?filter[status]=expired")

      assert %{"data" => entries} = json_response(conn, 200)
      assert length(entries) == 1
      assert hd(entries)["attributes"]["status"] == "expired"
    end

    test "returns empty list when accessing another account's grocery item (tenant isolation)",
         %{
           conn: conn,
           token: token
         } do
      {other_account, other_user} = create_account_and_user()
      other_item = create_grocery_item(other_account, other_user)
      _other_entry = create_inventory_entry(other_account, other_user, other_item)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/grocery_items/#{other_item.id}/inventory_entries")

      # Tenant isolation means entries outside user's tenant are not visible
      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "POST /api/json/grocery_items/:grocery_item_id/inventory_entries" do
    test "creates a new entry for the grocery item", %{
      conn: conn,
      token: token,
      grocery_item: item
    } do
      payload = %{
        "data" => %{
          "type" => "inventory_entry",
          "attributes" => %{
            "quantity" => "10",
            "unit" => "kg",
            "status" => "available"
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/grocery_items/#{item.id}/inventory_entries", payload)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["type"] == "inventory_entry"
      assert data["attributes"]["quantity"] == "10"
      assert data["attributes"]["unit"] == "kg"
      assert data["attributes"]["status"] == "available"
    end

    test "returns validation error when quantity is missing", %{
      conn: conn,
      token: token,
      grocery_item: item
    } do
      payload = %{
        "data" => %{
          "type" => "inventory_entry",
          "attributes" => %{
            "unit" => "kg"
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/grocery_items/#{item.id}/inventory_entries", payload)

      assert %{"errors" => errors} = json_response(conn, 400)
      assert length(errors) > 0
    end
  end

  describe "PATCH /api/json/grocery_items/:grocery_item_id/inventory_entries/:id" do
    test "updates an existing entry", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      grocery_item: item
    } do
      entry = create_inventory_entry(account, user, item, %{quantity: Decimal.new("5")})

      payload = %{
        "data" => %{
          "type" => "inventory_entry",
          "id" => entry.id,
          "attributes" => %{
            "quantity" => "15",
            "status" => "expired"
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/grocery_items/#{item.id}/inventory_entries/#{entry.id}", payload)

      assert %{"data" => data} = json_response(conn, 200)
      assert data["attributes"]["quantity"] == "15"
      assert data["attributes"]["status"] == "expired"
    end
  end

  describe "DELETE /api/json/grocery_items/:grocery_item_id/inventory_entries/:id" do
    test "deletes an entry from the grocery item", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      grocery_item: item
    } do
      entry = create_inventory_entry(account, user, item, %{quantity: Decimal.new("5")})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/json/grocery_items/#{item.id}/inventory_entries/#{entry.id}")

      # AshJsonApi returns 200 with deleted resource data by default
      assert %{"data" => _} = json_response(conn, 200)

      # Verify entry is deleted by trying to fetch entries
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/grocery_items/#{item.id}/inventory_entries")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 403 or 404 when deleting another account's entry (tenant isolation)", %{
      conn: conn,
      token: token
    } do
      {other_account, other_user} = create_account_and_user()
      other_item = create_grocery_item(other_account, other_user)
      other_entry = create_inventory_entry(other_account, other_user, other_item)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/json/grocery_items/#{other_item.id}/inventory_entries/#{other_entry.id}")

      # Tenant isolation returns 404 (entry not found in user's tenant) or 403
      assert conn.status in [403, 404]
    end
  end
end
