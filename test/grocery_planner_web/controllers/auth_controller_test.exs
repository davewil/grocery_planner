defmodule GroceryPlannerWeb.AuthControllerTest do
  use GroceryPlannerWeb.ConnCase
  import GroceryPlanner.InventoryTestHelpers

  setup do
    account = create_account()
    user = create_user(account)
    %{account: account, user: user}
  end

  test "sign_in logs in user with valid credentials", %{conn: conn, user: user} do
    conn =
      post(conn, "/auth/sign-in", %{
        "user" => %{"email" => user.email, "password" => "password123456"}
      })

    assert redirected_to(conn) == "/dashboard"
    assert get_session(conn, :user_id)
  end

  test "sign_in fails with invalid credentials", %{conn: conn, user: user} do
    conn =
      post(conn, "/auth/sign-in", %{
        "user" => %{"email" => user.email, "password" => "wrongpassword"}
      })

    assert redirected_to(conn) == "/sign-in"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
    refute get_session(conn, :user_id)
  end

  test "sign_in fails with non-existent email", %{conn: conn} do
    conn =
      post(conn, "/auth/sign-in", %{
        "user" => %{"email" => "nonexistent@example.com", "password" => "password123"}
      })

    assert redirected_to(conn) == "/sign-in"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
    refute get_session(conn, :user_id)
  end

  test "sign_out logs out user", %{conn: conn, user: user} do
    conn =
      conn
      # Mock login
      |> init_test_session(%{user_id: user.id})
      |> delete("/auth/sign-out")

    assert redirected_to(conn) == "/"
    assert conn.private.plug_session_info == :drop
  end
end
