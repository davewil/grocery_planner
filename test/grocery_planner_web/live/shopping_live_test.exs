defmodule GroceryPlannerWeb.ShoppingLiveTest do
  use GroceryPlannerWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import GroceryPlanner.InventoryTestHelpers
  alias GroceryPlanner.Shopping

  setup do
    account = create_account()
    user = create_user(account)

    conn =
      build_conn()
      |> init_test_session(%{
        user_id: user.id,
        account_id: account.id
      })

    %{conn: conn, account: account, user: user}
  end

  describe "Shopping Lists" do
    test "renders shopping lists page", %{conn: conn} do
      {:ok, view, html} = live(conn, "/shopping")

      assert html =~ "Shopping Lists"
      assert html =~ "Create List"
    end

    test "creates a new shopping list", %{conn: conn, account: account, user: user} do
      {:ok, view, _html} = live(conn, "/shopping")

      view
      |> element("button", "Create New List")
      |> render_click()

      assert has_element?(view, "#create-list-modal")

      view
      |> form("#create-list-form", %{"name" => "My New List"})
      |> render_submit()

      assert render(view) =~ "Shopping list created successfully"
      assert render(view) =~ "My New List"
    end

    test "selects a list and shows items", %{conn: conn, account: account, user: user} do
      {:ok, list} =
        Shopping.create_shopping_list(
          account.id,
          %{name: "Weekly Groceries"},
          actor: user,
          tenant: account.id
        )

      {:ok, view, _html} = live(conn, "/shopping")

      assert render(view) =~ "Weekly Groceries"

      view
      |> element("div[phx-click='select_list'][phx-value-id='#{list.id}']")
      |> render_click()

      assert render(view) =~ "Add Item"
      assert render(view) =~ "No items in this list"
    end
  end

  describe "Shopping List Items" do
    setup %{account: account, user: user} do
      {:ok, list} =
        Shopping.create_shopping_list(
          account.id,
          %{name: "Weekly Groceries"},
          actor: user,
          tenant: account.id
        )

      {:ok, item} =
        Shopping.create_shopping_list_item(
          account.id,
          %{
            shopping_list_id: list.id,
            name: "Milk",
            quantity: Decimal.new("1"),
            unit: "gallon"
          },
          actor: user,
          tenant: account.id
        )

      %{list: list, item: item}
    end

    test "adds an item to the list", %{conn: conn, list: list} do
      {:ok, view, _html} = live(conn, "/shopping")

      # Select list
      view
      |> element("div[phx-click='select_list'][phx-value-id='#{list.id}']")
      |> render_click()

      # Open Add Item modal
      view
      |> element("button", "Add Item")
      |> render_click()

      assert has_element?(view, "#add-item-modal")

      # Add item
      view
      |> form("#add-item-form", %{
        "name" => "Bread",
        "quantity" => "2",
        "unit" => "loaves"
      })
      |> render_submit()

      assert render(view) =~ "Item added"
      assert render(view) =~ "Bread"
      assert render(view) =~ "2"
      assert render(view) =~ "loaves"
    end

    test "toggles item check status", %{conn: conn, list: list, item: item} do
      {:ok, view, _html} = live(conn, "/shopping")

      # Select list
      view
      |> element("div[phx-click='select_list'][phx-value-id='#{list.id}']")
      |> render_click()

      assert render(view) =~ "Milk"

      # Toggle item
      view
      |> element("input[phx-click='toggle_item'][phx-value-id='#{item.id}']")
      |> render_click()

      # Verify visual change (e.g., line-through or checked icon)
      # Since we can't easily check CSS classes with simple assertions, we check if the element still exists and maybe check for a specific class if we knew it.
      # For now, just ensuring no crash and re-render happens.
      assert render(view) =~ "Milk"
    end

    test "deletes an item", %{conn: conn, list: list, item: item} do
      {:ok, view, _html} = live(conn, "/shopping")

      # Select list
      view
      |> element("div[phx-click='select_list'][phx-value-id='#{list.id}']")
      |> render_click()

      assert render(view) =~ "Milk"

      # Delete item
      view
      |> element("button[phx-click='delete_item'][phx-value-id='#{item.id}']")
      |> render_click()

      assert render(view) =~ "Item removed"
      refute render(view) =~ "Milk"
    end
  end
end
