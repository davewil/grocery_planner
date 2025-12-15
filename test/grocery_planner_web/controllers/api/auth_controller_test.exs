defmodule GroceryPlannerWeb.Api.AuthControllerTest do
  use GroceryPlannerWeb.ConnCase, async: true
  import GroceryPlanner.InventoryTestHelpers

  setup do
    {account, user} = create_account_and_user()
    %{account: account, user: user}
  end

  describe "sign_in" do
    test "returns token with valid credentials", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/sign-in", %{
          "email" => user.email,
          "password" => "password123456"
        })

      assert %{"data" => %{"token" => token}} = json_response(conn, 200)
      assert is_binary(token)
    end

    test "returns 401 with invalid credentials", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/sign-in", %{
          "email" => user.email,
          "password" => "wrongpassword"
        })

      assert json_response(conn, 401)
    end
  end
end
