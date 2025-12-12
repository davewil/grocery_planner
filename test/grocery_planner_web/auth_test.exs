defmodule GroceryPlannerWeb.AuthTest do
  use GroceryPlannerWeb.ConnCase
  import GroceryPlanner.InventoryTestHelpers
  alias GroceryPlannerWeb.Auth

  setup do
    account = create_account()
    user = create_user(account)
    %{account: account, user: user}
  end

  describe "init/1" do
    test "returns options" do
      assert Auth.init([]) == []
    end
  end

  describe "fetch_current_user/2" do
    test "assigns user and account when session has valid user_id", %{
      conn: conn,
      user: user,
      account: account
    } do
      conn =
        conn
        |> init_test_session(%{user_id: user.id})
        |> Auth.fetch_current_user([])

      assert conn.assigns.current_user.id == user.id
      assert conn.assigns.current_account.id == account.id
    end

    test "assigns nil when session has no user_id", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> Auth.fetch_current_user([])

      refute conn.assigns.current_user
      refute conn.assigns.current_account
    end

    test "assigns nil when user not found", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{user_id: Ash.UUID.generate()})
        |> Auth.fetch_current_user([])

      refute conn.assigns.current_user
      refute conn.assigns.current_account
    end
  end

  describe "require_authenticated_user/2" do
    test "halts and redirects if user is not authenticated", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> fetch_flash()
        |> Auth.require_authenticated_user([])

      assert conn.halted
      assert redirected_to(conn) == "/sign-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "continues if user is authenticated", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{})
        |> fetch_flash()
        |> assign(:current_user, user)
        |> Auth.require_authenticated_user([])

      refute conn.halted
    end
  end
end
