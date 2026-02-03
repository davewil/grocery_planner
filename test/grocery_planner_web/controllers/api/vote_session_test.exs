defmodule GroceryPlannerWeb.Api.VoteSessionTest do
  @moduledoc """
  Behavioral tests for the MealPlanVoteSession JSON:API endpoints.
  Tests the top-level resource pattern: /vote_sessions
  """
  use GroceryPlannerWeb.ConnCase, async: true
  import GroceryPlanner.MealPlanningTestHelpers

  setup do
    {account, user} = create_account_and_user()
    token = Phoenix.Token.sign(GroceryPlannerWeb.Endpoint, "user auth", user.id)
    %{account: account, user: user, token: token}
  end

  describe "GET /api/json/vote_sessions" do
    test "returns 401 without authentication token", %{conn: conn} do
      conn = get(conn, "/api/json/vote_sessions")
      assert json_response(conn, 401)
    end

    test "returns empty list when no vote sessions exist", %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/vote_sessions")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns vote sessions belonging to the account", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      session = create_vote_session(account, user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/vote_sessions")

      assert %{"data" => [data]} = json_response(conn, 200)
      assert data["id"] == session.id
      assert data["type"] == "vote_session"
      assert data["attributes"]["status"] == "open"
    end

    test "returns empty list when accessing another account's sessions (tenant isolation)", %{
      conn: conn,
      token: token
    } do
      {other_account, other_user} = create_account_and_user()
      _other_session = create_vote_session(other_account, other_user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/vote_sessions")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/json/vote_sessions/:id" do
    test "returns a specific vote session", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      session = create_vote_session(account, user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/vote_sessions/#{session.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == session.id
      assert data["attributes"]["status"] == "open"
    end

    test "returns 404 for non-existent session", %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/vote_sessions/#{Ecto.UUID.generate()}")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/json/vote_sessions" do
    test "creates a new vote session", %{conn: conn, token: token, account: account} do
      payload = %{
        "data" => %{
          "type" => "vote_session",
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
        |> post("/api/json/vote_sessions", payload)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["type"] == "vote_session"
      assert data["attributes"]["status"] == "open"
      assert data["attributes"]["starts_at"] != nil
      assert data["attributes"]["ends_at"] != nil
    end

    test "returns error when session already exists", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      _existing_session = create_vote_session(account, user)

      payload = %{
        "data" => %{
          "type" => "vote_session",
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
        |> post("/api/json/vote_sessions", payload)

      assert %{"errors" => errors} = json_response(conn, 400)
      assert length(errors) > 0
    end
  end

  describe "PATCH /api/json/vote_sessions/:id/close" do
    test "closes an open vote session", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      session = create_vote_session(account, user)

      payload = %{
        "data" => %{
          "type" => "vote_session",
          "id" => session.id
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/vote_sessions/#{session.id}/close", payload)

      assert %{"data" => data} = json_response(conn, 200)
      assert data["attributes"]["status"] == "closed"
    end
  end

  describe "DELETE /api/json/vote_sessions/:id" do
    test "deletes a vote session", %{
      conn: conn,
      token: token,
      account: account,
      user: user
    } do
      session = create_vote_session(account, user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/json/vote_sessions/#{session.id}")

      assert %{"data" => _} = json_response(conn, 200)

      # Verify session is deleted
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/vote_sessions")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns error when deleting another account's session (policy denies)", %{
      conn: conn,
      token: token
    } do
      {other_account, other_user} = create_account_and_user()
      other_session = create_vote_session(other_account, other_user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/json/vote_sessions/#{other_session.id}")

      assert conn.status in [403, 404]
    end
  end
end
