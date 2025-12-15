defmodule GroceryPlannerWeb.Auth.SignUpLiveTest do
  use GroceryPlannerWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "SignUpLive" do
    test "renders sign up page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/sign-up")

      assert html =~ "Create Account"
      assert html =~ "Already have an account?"
    end

    test "creates account successfully with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign-up")

      view
      |> form("#sign-up-form",
        user: %{
          name: "Test User",
          email: "testuser#{:rand.uniform(10000)}@example.com",
          password: "securepassword123",
          account_name: "Test Household"
        }
      )
      |> render_submit()

      assert_redirected(view, "/sign-in")
    end

    test "stays on page when missing required fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign-up")

      view
      |> form("#sign-up-form",
        user: %{
          name: "Test User",
          email: "",
          password: "securepassword123",
          account_name: "Test Household"
        }
      )
      |> render_submit()

      # Should not redirect when there's an error
      assert view
             |> element("form#sign-up-form")
             |> has_element?()
    end

    test "stays on page when account creation fails due to duplicate email", %{conn: conn} do
      # First, create an account with a specific email
      {:ok, view, _html} = live(conn, "/sign-up")
      unique_email = "duplicate#{:rand.uniform(10000)}@example.com"

      view
      |> form("#sign-up-form",
        user: %{
          name: "First User",
          email: unique_email,
          password: "securepassword123",
          account_name: "First Household"
        }
      )
      |> render_submit()

      assert_redirected(view, "/sign-in")

      # Try to create another account with the same email
      {:ok, view2, _html} = live(conn, "/sign-up")

      view2
      |> form("#sign-up-form",
        user: %{
          name: "Second User",
          email: unique_email,
          password: "securepassword123",
          account_name: "Second Household"
        }
      )
      |> render_submit()

      # Should stay on the sign-up page with the form still present
      assert view2
             |> element("form#sign-up-form")
             |> has_element?()
    end
  end
end
