defmodule GroceryPlannerWeb.Auth.SignInLiveTest do
  use GroceryPlannerWeb.ConnCase
  import Phoenix.LiveViewTest

  test "renders sign in page", %{conn: conn} do
    {:ok, view, html} = live(conn, "/sign-in")

    assert html =~ "Sign In"
    assert html =~ "have an account?"
    assert has_element?(view, "form#sign-in-form")
  end
end
