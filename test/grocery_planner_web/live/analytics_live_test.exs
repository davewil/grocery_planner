defmodule GroceryPlannerWeb.AnalyticsLiveTest do
  use GroceryPlannerWeb.ConnCase
  import Phoenix.LiveViewTest
  import GroceryPlanner.InventoryTestHelpers

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

  describe "Analytics Dashboard" do
    test "renders dashboard with empty state", %{conn: conn} do
      {:ok, view, html} = live(conn, "/analytics")

      assert html =~ "Analytics Dashboard"
      assert html =~ "Total Inventory"
      assert html =~ "No inventory data available"
    end

    test "renders dashboard with data", %{conn: conn, account: account, user: user} do
      # Create some inventory items
      item1 = create_grocery_item(account, user, %{name: "Apple", category_id: create_category(account, user, %{name: "Fruits"}).id})
      item2 = create_grocery_item(account, user, %{name: "Milk", category_id: create_category(account, user, %{name: "Dairy"}).id})

      create_inventory_entry(account, user, item1, %{
        quantity: Decimal.new(10),
        purchase_price: Money.new(5, :USD), # $5.00
        use_by_date: Date.add(Date.utc_today(), 5) # Expiring soon
      })

      create_inventory_entry(account, user, item2, %{
        quantity: Decimal.new(2),
        purchase_price: Money.new(3, :USD), # $3.00
        use_by_date: Date.add(Date.utc_today(), 30) # Not expiring soon
      })

      {:ok, view, html} = live(conn, "/analytics")

      assert html =~ "Analytics Dashboard"
      assert html =~ "Total Inventory"
      
      # Check metrics
      assert has_element?(view, "h3", "2") # Total items
      assert html =~ "$8.00" # Total value
      assert has_element?(view, "h3", "1") # Expiring soon (Apple)
      
      # Check category breakdown
      assert html =~ "Fruits"
      assert html =~ "Dairy"
    end
  end
end
