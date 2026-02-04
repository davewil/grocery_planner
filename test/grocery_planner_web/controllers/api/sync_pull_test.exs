defmodule GroceryPlannerWeb.Api.SyncPullTest do
  @moduledoc """
  Behavioral tests for US-008 remaining: Sync metadata and conflict detection.
  """
  use GroceryPlannerWeb.ConnCase, async: true
  import GroceryPlanner.InventoryTestHelpers

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

  # --- Pull endpoint tests ---

  describe "GET /api/sync/pull - basic behavior" do
    test "returns sync metadata with server_time, has_more, and count", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      create_grocery_item(account, user, %{name: "Pull Test Item"})

      conn =
        conn
        |> auth_conn(token)
        |> get("/api/sync/pull", %{"type" => "grocery_item"})

      assert %{
               "data" => data,
               "meta" => %{
                 "server_time" => server_time,
                 "has_more" => false,
                 "count" => count
               }
             } = json_response(conn, 200)

      assert {:ok, _, _} = DateTime.from_iso8601(server_time)
      assert count >= 1
      assert is_list(data)
    end

    test "returns 401 when no auth token", %{conn: conn} do
      conn = get(conn, "/api/sync/pull", %{"type" => "grocery_item"})
      assert json_response(conn, 401)
    end

    test "returns 400 when type parameter is missing", %{conn: conn, token: token} do
      conn =
        conn
        |> auth_conn(token)
        |> get("/api/sync/pull")

      assert %{"errors" => [error]} = json_response(conn, 400)
      assert error["code"] == "invalid_request"
    end

    test "returns 400 for unknown resource type", %{conn: conn, token: token} do
      conn =
        conn
        |> auth_conn(token)
        |> get("/api/sync/pull", %{"type" => "nonexistent"})

      assert %{"errors" => [error]} = json_response(conn, 400)
      assert error["code"] == "unknown_type"
    end
  end

  describe "GET /api/sync/pull - has_more pagination" do
    test "has_more is true when results exceed limit", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      # Create 3 items, request with limit=2
      for i <- 1..3, do: create_grocery_item(account, user, %{name: "Item #{i}"})

      conn =
        conn
        |> auth_conn(token)
        |> get("/api/sync/pull", %{"type" => "grocery_item", "limit" => "2"})

      assert %{
               "meta" => %{"has_more" => true, "count" => 2},
               "data" => data
             } = json_response(conn, 200)

      assert length(data) == 2
    end

    test "has_more is false when results fit within limit", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      create_grocery_item(account, user, %{name: "Only Item"})

      conn =
        conn
        |> auth_conn(token)
        |> get("/api/sync/pull", %{"type" => "grocery_item", "limit" => "10"})

      assert %{"meta" => %{"has_more" => false}} = json_response(conn, 200)
    end
  end

  describe "GET /api/sync/pull - since filtering" do
    test "filters records by since timestamp", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      _old = create_grocery_item(account, user, %{name: "Old Item"})
      since = DateTime.add(DateTime.utc_now(), 1, :second)
      Process.sleep(1100)
      _new = create_grocery_item(account, user, %{name: "New Item"})

      conn =
        conn
        |> auth_conn(token)
        |> get("/api/sync/pull", %{
          "type" => "grocery_item",
          "since" => DateTime.to_iso8601(since)
        })

      assert %{"data" => data, "meta" => %{"count" => 1}} = json_response(conn, 200)
      assert length(data) == 1
      assert hd(data)["name"] == "New Item"
    end
  end

  describe "GET /api/sync/pull - record serialization" do
    test "returns full record attributes in data", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      item = create_grocery_item(account, user, %{name: "Serialization Test"})

      conn =
        conn
        |> auth_conn(token)
        |> get("/api/sync/pull", %{"type" => "grocery_item"})

      assert %{"data" => [record | _]} = json_response(conn, 200)
      assert record["id"] == item.id
      assert record["name"] == "Serialization Test"
      assert record["updated_at"] != nil
      assert record["created_at"] != nil
    end
  end

  describe "GET /api/sync/pull - multiple resource types" do
    test "works for shopping_list type", %{conn: conn, token: token, account: account, user: user} do
      {:ok, _list} =
        Shopping.create_shopping_list(account.id, %{name: "Pull Test"},
          actor: user,
          tenant: account.id
        )

      conn =
        conn
        |> auth_conn(token)
        |> get("/api/sync/pull", %{"type" => "shopping_list"})

      assert %{"data" => data, "meta" => %{"count" => count}} = json_response(conn, 200)
      assert count >= 1
      assert is_list(data)
    end
  end

  # --- Conflict detection tests ---

  describe "POST /api/sync/batch - conflict detection on update" do
    test "succeeds when if_unmodified_since is after record's updated_at", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      item = create_grocery_item(account, user, %{name: "Conflict Test"})
      # Use a timestamp in the future (after the record was last modified)
      future = DateTime.add(DateTime.utc_now(), 60, :second)

      payload = %{
        "operations" => [
          %{
            "op" => "update",
            "type" => "grocery_item",
            "id" => item.id,
            "data" => %{"name" => "Updated"},
            "if_unmodified_since" => DateTime.to_iso8601(future)
          }
        ]
      }

      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", payload)

      assert %{"results" => [result]} = json_response(conn, 200)
      assert result["status"] == "ok"
    end

    test "returns conflict error when record was modified after if_unmodified_since", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      item = create_grocery_item(account, user, %{name: "Will Conflict"})
      # Use a timestamp well in the past
      past = DateTime.add(DateTime.utc_now(), -3600, :second)

      payload = %{
        "operations" => [
          %{
            "op" => "update",
            "type" => "grocery_item",
            "id" => item.id,
            "data" => %{"name" => "Should Fail"},
            "if_unmodified_since" => DateTime.to_iso8601(past)
          }
        ]
      }

      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", payload)

      assert %{"results" => [result]} = json_response(conn, 200)
      assert result["status"] == "error"
      assert result["error"]["code"] == "conflict"
      assert result["current"]["updated_at"] != nil
    end
  end

  describe "POST /api/sync/batch - conflict detection on delete" do
    test "returns conflict error on delete when record was modified", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      item = create_grocery_item(account, user, %{name: "Delete Conflict"})
      past = DateTime.add(DateTime.utc_now(), -3600, :second)

      payload = %{
        "operations" => [
          %{
            "op" => "delete",
            "type" => "grocery_item",
            "id" => item.id,
            "if_unmodified_since" => DateTime.to_iso8601(past)
          }
        ]
      }

      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", payload)

      assert %{"results" => [result]} = json_response(conn, 200)
      assert result["status"] == "error"
      assert result["error"]["code"] == "conflict"
    end
  end

  describe "POST /api/sync/batch - backward compatibility" do
    test "operations without if_unmodified_since still work", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      item = create_grocery_item(account, user, %{name: "No Conflict Check"})

      payload = %{
        "operations" => [
          %{
            "op" => "update",
            "type" => "grocery_item",
            "id" => item.id,
            "data" => %{"name" => "Updated Without Check"}
          }
        ]
      }

      conn =
        conn
        |> auth_conn(token)
        |> post("/api/sync/batch", payload)

      assert %{"results" => [result]} = json_response(conn, 200)
      assert result["status"] == "ok"
    end
  end
end
