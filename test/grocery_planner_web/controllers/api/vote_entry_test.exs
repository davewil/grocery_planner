defmodule GroceryPlannerWeb.Api.VoteEntryTest do
  @moduledoc """
  Behavioral tests for the MealPlanVoteEntry JSON:API endpoints.
  Tests the nested resource pattern: /vote_sessions/:vote_session_id/entries
  """
  use GroceryPlannerWeb.ConnCase, async: true
  import GroceryPlanner.MealPlanningTestHelpers

  setup do
    {account, user} = create_account_and_user()
    token = Phoenix.Token.sign(GroceryPlannerWeb.Endpoint, "user auth", user.id)
    recipe = create_recipe(account, user)
    session = create_vote_session(account, user)
    %{account: account, user: user, token: token, recipe: recipe, session: session}
  end

  describe "GET /api/json/vote_sessions/:session_id/entries" do
    test "returns 401 without authentication token", %{conn: conn, session: session} do
      conn = get(conn, "/api/json/vote_sessions/#{session.id}/entries")
      assert json_response(conn, 401)
    end

    test "returns empty list when no entries exist", %{conn: conn, token: token, session: session} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/vote_sessions/#{session.id}/entries")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns vote entries for the session", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      recipe: recipe,
      session: session
    } do
      entry = create_vote_entry(account, user, session, recipe)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/vote_sessions/#{session.id}/entries")

      assert %{"data" => [data]} = json_response(conn, 200)
      assert data["id"] == entry.id
      assert data["type"] == "vote_entry"
      assert data["attributes"]["recipe_id"] == recipe.id
    end

    test "returns empty list when accessing another account's entries (tenant isolation)", %{
      conn: conn,
      token: token,
      session: session
    } do
      {other_account, other_user} = create_account_and_user()
      other_recipe = create_recipe(other_account, other_user)
      other_session = create_vote_session(other_account, other_user)
      _other_entry = create_vote_entry(other_account, other_user, other_session, other_recipe)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/vote_sessions/#{session.id}/entries")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/json/vote_sessions/:session_id/entries/:id" do
    test "returns a specific vote entry", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      recipe: recipe,
      session: session
    } do
      entry = create_vote_entry(account, user, session, recipe)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/vote_sessions/#{session.id}/entries/#{entry.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == entry.id
      assert data["attributes"]["recipe_id"] == recipe.id
    end

    test "returns 404 for non-existent entry", %{conn: conn, token: token, session: session} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/vote_sessions/#{session.id}/entries/#{Ecto.UUID.generate()}")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/json/vote_sessions/:session_id/entries" do
    test "creates a new vote entry (casts a vote)", %{
      conn: conn,
      token: token,
      recipe: recipe,
      session: session
    } do
      payload = %{
        "data" => %{
          "type" => "vote_entry",
          "attributes" => %{
            "recipe_id" => recipe.id
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/vote_sessions/#{session.id}/entries", payload)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["type"] == "vote_entry"
      assert data["attributes"]["recipe_id"] == recipe.id
    end

    test "returns error when voting for same recipe twice", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      recipe: recipe,
      session: session
    } do
      _existing_vote = create_vote_entry(account, user, session, recipe)

      payload = %{
        "data" => %{
          "type" => "vote_entry",
          "attributes" => %{
            "recipe_id" => recipe.id
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/vote_sessions/#{session.id}/entries", payload)

      assert %{"errors" => errors} = json_response(conn, 400)
      assert length(errors) > 0
    end

    test "returns error when voting on closed session", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      session: session
    } do
      # Close the session
      {:ok, _closed_session} =
        GroceryPlanner.MealPlanning.close_vote_session(session, actor: user, tenant: account.id)

      recipe2 = create_recipe(account, user, %{name: "Another Recipe"})

      payload = %{
        "data" => %{
          "type" => "vote_entry",
          "attributes" => %{
            "recipe_id" => recipe2.id
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/vote_sessions/#{session.id}/entries", payload)

      assert %{"errors" => errors} = json_response(conn, 400)
      assert length(errors) > 0
    end

    test "allows voting for different recipes", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      recipe: recipe,
      session: session
    } do
      _vote1 = create_vote_entry(account, user, session, recipe)
      recipe2 = create_recipe(account, user, %{name: "Second Recipe"})

      payload = %{
        "data" => %{
          "type" => "vote_entry",
          "attributes" => %{
            "recipe_id" => recipe2.id
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/vote_sessions/#{session.id}/entries", payload)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["attributes"]["recipe_id"] == recipe2.id
    end
  end

  describe "DELETE /api/json/vote_sessions/:session_id/entries/:id" do
    test "deletes a vote entry (retracts a vote)", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      recipe: recipe,
      session: session
    } do
      entry = create_vote_entry(account, user, session, recipe)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/json/vote_sessions/#{session.id}/entries/#{entry.id}")

      assert %{"data" => _} = json_response(conn, 200)

      # Verify entry is deleted
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/vote_sessions/#{session.id}/entries")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns error when deleting another account's entry (policy denies)", %{
      conn: conn,
      token: token
    } do
      {other_account, other_user} = create_account_and_user()
      other_recipe = create_recipe(other_account, other_user)
      other_session = create_vote_session(other_account, other_user)
      other_entry = create_vote_entry(other_account, other_user, other_session, other_recipe)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/json/vote_sessions/#{other_session.id}/entries/#{other_entry.id}")

      assert conn.status in [403, 404]
    end
  end
end
