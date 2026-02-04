defmodule GroceryPlannerWeb.Api.SyncBatchTest do
  @moduledoc """
  Behavioral tests for US-009: Bulk Operations for Sync Efficiency.

  Tests verify that:
  - POST /api/sync/batch accepts array of operations
  - Supports mixed create/update/delete operations
  - Returns per-operation success/failure status
  - Atomic option rolls back all on failure
  - temp_id mapping works for offline-created resources
  - Authentication is required
  - Server time is returned in responses
  """
  use GroceryPlannerWeb.ConnCase, async: true
  import GroceryPlanner.InventoryTestHelpers

  alias GroceryPlanner.Inventory
  alias GroceryPlanner.Shopping

  setup do
    {account, user} = create_account_and_user()
    token = Phoenix.Token.sign(GroceryPlannerWeb.Endpoint, "user auth", user.id)
    %{account: account, user: user, token: token}
  end

  defp auth_conn(conn, token) do
    conn
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/json")
  end

  describe "GET /api/sync/status" do
    test "returns server time and API version", %{conn: conn, token: token} do
      conn =
        conn
        |> auth_conn(token)
        |> get("/api/sync/status")

      assert %{
               "data" => %{
                 "server_time" => server_time,
                 "api_version" => "1.0"
               },
               "jsonapi" => %{"version" => "1.0"}
             } = json_response(conn, 200)

      assert {:ok, _, _} = DateTime.from_iso8601(server_time)
    end
  end

  describe "POST /api/sync/batch - authentication" do
    test "returns 401 when no auth token provided", %{conn: conn} do
      conn = post(conn, "/api/sync/batch", %{"operations" => []})

      assert json_response(conn, 401)
    end
  end

  describe "POST /api/sync/batch - validation" do
    test "returns 400 when operations array is missing", %{conn: conn, token: token} do
      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", %{})

      assert %{"errors" => [error]} = json_response(conn, 400)
      assert error["code"] == "invalid_request"
    end
  end

  describe "POST /api/sync/batch - create operations" do
    test "creates a shopping list", %{conn: conn, token: token} do
      payload = %{
        "operations" => [
          %{
            "op" => "create",
            "type" => "shopping_list",
            "data" => %{"name" => "Batch Created List"}
          }
        ]
      }

      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", payload)

      assert %{"results" => [result], "server_time" => _} = json_response(conn, 200)
      assert result["op"] == "create"
      assert result["type"] == "shopping_list"
      assert result["status"] == "ok"
      assert is_binary(result["id"])
      assert result["data"]["updated_at"] != nil
    end

    test "creates multiple resources in one batch", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      {:ok, list} =
        Shopping.create_shopping_list(account.id, %{name: "Parent List"},
          actor: user,
          tenant: account.id
        )

      payload = %{
        "operations" => [
          %{
            "op" => "create",
            "type" => "grocery_item",
            "data" => %{"name" => "Batch Apples"}
          },
          %{
            "op" => "create",
            "type" => "shopping_list_item",
            "data" => %{"name" => "Batch Milk", "shopping_list_id" => list.id}
          }
        ]
      }

      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", payload)

      assert %{"results" => results} = json_response(conn, 200)
      assert length(results) == 2
      assert Enum.all?(results, &(&1["status"] == "ok"))
    end

    test "returns temp_id in create response for offline mapping", %{conn: conn, token: token} do
      payload = %{
        "operations" => [
          %{
            "op" => "create",
            "type" => "grocery_item",
            "temp_id" => "client-temp-123",
            "data" => %{"name" => "Offline Created Item"}
          }
        ]
      }

      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", payload)

      assert %{"results" => [result]} = json_response(conn, 200)
      assert result["temp_id"] == "client-temp-123"
      assert result["status"] == "ok"
      assert is_binary(result["id"])
    end
  end

  describe "POST /api/sync/batch - update operations" do
    test "updates an existing resource", %{conn: conn, token: token, account: account, user: user} do
      item = create_grocery_item(account, user, %{name: "Original Name"})

      payload = %{
        "operations" => [
          %{
            "op" => "update",
            "type" => "grocery_item",
            "id" => item.id,
            "data" => %{"name" => "Updated Name"}
          }
        ]
      }

      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", payload)

      assert %{"results" => [result]} = json_response(conn, 200)
      assert result["status"] == "ok"
      assert result["id"] == item.id
    end

    test "returns error for non-existent resource update", %{conn: conn, token: token} do
      payload = %{
        "operations" => [
          %{
            "op" => "update",
            "type" => "grocery_item",
            "id" => Ash.UUID.generate(),
            "data" => %{"name" => "Won't Work"}
          }
        ]
      }

      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", payload)

      assert %{"results" => [result]} = json_response(conn, 200)
      assert result["status"] == "error"
    end
  end

  describe "POST /api/sync/batch - delete operations" do
    test "soft-deletes an existing resource", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      item = create_grocery_item(account, user, %{name: "To Be Deleted"})

      payload = %{
        "operations" => [
          %{
            "op" => "delete",
            "type" => "grocery_item",
            "id" => item.id
          }
        ]
      }

      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", payload)

      assert %{"results" => [result]} = json_response(conn, 200)
      assert result["status"] == "ok"
      assert result["id"] == item.id

      # Verify soft delete: item excluded from normal reads
      {:ok, items} = Inventory.list_grocery_items(actor: user, tenant: account.id)
      refute Enum.any?(items, &(&1.id == item.id))

      # But visible via sync action
      {:ok, synced} = Inventory.sync_grocery_items(nil, actor: user, tenant: account.id)
      deleted = Enum.find(synced, &(&1.id == item.id))
      assert deleted.deleted_at != nil
    end
  end

  describe "POST /api/sync/batch - mixed operations" do
    test "handles create, update, and delete in a single batch", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      existing = create_grocery_item(account, user, %{name: "Will Update"})
      to_delete = create_grocery_item(account, user, %{name: "Will Delete"})

      payload = %{
        "operations" => [
          %{
            "op" => "create",
            "type" => "grocery_item",
            "data" => %{"name" => "New Item"}
          },
          %{
            "op" => "update",
            "type" => "grocery_item",
            "id" => existing.id,
            "data" => %{"name" => "Updated Item"}
          },
          %{
            "op" => "delete",
            "type" => "grocery_item",
            "id" => to_delete.id
          }
        ]
      }

      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", payload)

      assert %{"results" => results} = json_response(conn, 200)
      assert length(results) == 3

      [create_result, update_result, delete_result] = results

      assert create_result["op"] == "create"
      assert create_result["status"] == "ok"

      assert update_result["op"] == "update"
      assert update_result["status"] == "ok"

      assert delete_result["op"] == "delete"
      assert delete_result["status"] == "ok"
    end
  end

  describe "POST /api/sync/batch - error handling" do
    test "returns error for unknown resource type", %{conn: conn, token: token} do
      payload = %{
        "operations" => [
          %{
            "op" => "create",
            "type" => "nonexistent_type",
            "data" => %{"name" => "Test"}
          }
        ]
      }

      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", payload)

      assert %{"results" => [result]} = json_response(conn, 200)
      assert result["status"] == "error"
      assert result["error"]["code"] == "unknown_type"
    end

    test "returns per-operation errors without failing other operations", %{
      conn: conn,
      token: token
    } do
      payload = %{
        "operations" => [
          %{
            "op" => "create",
            "type" => "grocery_item",
            "data" => %{"name" => "Will Succeed"}
          },
          %{
            "op" => "update",
            "type" => "grocery_item",
            "id" => Ash.UUID.generate(),
            "data" => %{"name" => "Will Fail - Not Found"}
          }
        ]
      }

      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", payload)

      assert %{"results" => [success, failure]} = json_response(conn, 200)
      assert success["status"] == "ok"
      assert failure["status"] == "error"
    end
  end

  describe "POST /api/sync/batch - atomic mode" do
    test "commits all operations when all succeed", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      item = create_grocery_item(account, user, %{name: "Atomic Test"})

      payload = %{
        "atomic" => true,
        "operations" => [
          %{
            "op" => "create",
            "type" => "grocery_item",
            "data" => %{"name" => "Atomic New"}
          },
          %{
            "op" => "update",
            "type" => "grocery_item",
            "id" => item.id,
            "data" => %{"name" => "Atomic Updated"}
          }
        ]
      }

      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", payload)

      assert %{"results" => results} = json_response(conn, 200)
      assert length(results) == 2
      assert Enum.all?(results, &(&1["status"] == "ok"))
    end

    test "rolls back all operations when one fails", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      payload = %{
        "atomic" => true,
        "operations" => [
          %{
            "op" => "create",
            "type" => "grocery_item",
            "data" => %{"name" => "Should Be Rolled Back"}
          },
          %{
            "op" => "update",
            "type" => "grocery_item",
            "id" => Ash.UUID.generate(),
            "data" => %{"name" => "Will Fail"}
          }
        ]
      }

      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", payload)

      # Atomic failure returns 422
      assert %{"results" => results} = json_response(conn, 422)

      last = List.last(results)
      assert last["status"] == "error"

      # Verify the first create was rolled back
      {:ok, items} = Inventory.list_grocery_items(actor: user, tenant: account.id)
      refute Enum.any?(items, &(&1.name == "Should Be Rolled Back"))
    end
  end

  describe "POST /api/sync/batch - server_time" do
    test "returns server_time in response", %{conn: conn, token: token} do
      payload = %{"operations" => []}

      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", payload)

      assert %{"server_time" => server_time} = json_response(conn, 200)
      assert {:ok, _, _} = DateTime.from_iso8601(server_time)
    end
  end
end
