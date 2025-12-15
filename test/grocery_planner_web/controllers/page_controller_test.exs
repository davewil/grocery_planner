defmodule GroceryPlannerWeb.PageControllerTest do
  use GroceryPlannerWeb.ConnCase, async: true

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Smart Grocery Management"
  end
end
