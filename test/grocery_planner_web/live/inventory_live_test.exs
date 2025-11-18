defmodule GroceryPlannerWeb.InventoryLiveTest do
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

  describe "mount and navigation" do
    test "requires authentication", %{conn: conn} do
      conn = delete_session(conn, :user_id)

      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, "/inventory")
    end

    test "renders inventory page for authenticated user", %{conn: conn} do
      {:ok, view, html} = live(conn, "/inventory")

      assert html =~ "Inventory Management"
      assert html =~ "Manage your grocery items"
      assert has_element?(view, "button", "Grocery Items")
      assert has_element?(view, "button", "Current Inventory")
      assert has_element?(view, "button", "Categories")
      assert has_element?(view, "button", "Storage Locations")
    end

    test "defaults to Grocery Items tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      assert has_element?(view, "button[phx-value-tab='items']")
      assert has_element?(view, "button", "New Item")
    end

    test "switches to Current Inventory tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='inventory']")
      |> render_click()

      assert has_element?(view, "button", "New Entry")
      refute has_element?(view, "button", "New Item")
    end

    test "switches to Categories tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='categories']")
      |> render_click()

      assert has_element?(view, "button", "New Category")
      refute has_element?(view, "button", "New Item")
    end

    test "switches to Storage Locations tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='locations']")
      |> render_click()

      assert has_element?(view, "button", "New Location")
      refute has_element?(view, "button", "New Item")
    end
  end

  describe "Grocery Items tab" do
    test "shows New Item button only on Grocery Items tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      assert has_element?(view, "button", "New Item")

      view
      |> element("button[phx-value-tab='inventory']")
      |> render_click()

      refute has_element?(view, "button", "New Item")
    end

    test "displays existing grocery items", %{conn: conn, account: account, user: user} do
      item1 = create_grocery_item(account, user, %{name: "Milk", description: "Whole milk"})
      item2 = create_grocery_item(account, user, %{name: "Bread", description: "Whole wheat"})

      {:ok, _view, html} = live(conn, "/inventory")

      assert html =~ "Milk"
      assert html =~ "Whole milk"
      assert html =~ "Bread"
      assert html =~ "Whole wheat"
    end

    test "shows empty state when no items exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/inventory")

      assert html =~ "No grocery items yet"
      assert html =~ "New Item"
    end

    test "opens form when New Item is clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      refute has_element?(view, "form#item-form")

      view
      |> element("button", "New Item")
      |> render_click()

      assert has_element?(view, "form#item-form")
      assert has_element?(view, "input[name='item[name]']")
    end

    test "creates new grocery item", %{conn: conn, account: account, user: user} do
      category = create_category(account, user, %{name: "Dairy"})

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button", "New Item")
      |> render_click()

      view
      |> form("#item-form",
        item: %{
          name: "Cheese",
          description: "Cheddar cheese",
          default_unit: "lbs",
          category_id: category.id
        }
      )
      |> render_submit()

      assert render(view) =~ "Cheese"
      assert render(view) =~ "Cheddar cheese"
      refute has_element?(view, "form#item-form")
    end

    test "cancels form", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button", "New Item")
      |> render_click()

      assert has_element?(view, "form#item-form")

      view
      |> element("button", "Cancel")
      |> render_click()

      refute has_element?(view, "form#item-form")
    end

    test "deletes grocery item", %{conn: conn, account: account, user: user} do
      item = create_grocery_item(account, user, %{name: "Old Item"})

      {:ok, view, _html} = live(conn, "/inventory")

      assert render(view) =~ "Old Item"

      view
      |> element("button[phx-value-id='#{item.id}']", "Delete")
      |> render_click()

      refute render(view) =~ "Old Item"
    end
  end

  describe "Current Inventory tab" do
    test "displays inventory entries with item and location names", %{
      conn: conn,
      account: account,
      user: user
    } do
      item = create_grocery_item(account, user, %{name: "Milk"})
      location = create_storage_location(account, user, %{name: "Fridge"})

      create_inventory_entry(account, user, item, %{
        storage_location_id: location.id,
        quantity: Decimal.new("2"),
        unit: "L"
      })

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='inventory']")
      |> render_click()

      html = render(view)
      assert html =~ "Milk"
      assert html =~ "2 L"
      assert html =~ "Stored in: Fridge"
    end

    test "shows empty state when no entries exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='inventory']")
      |> render_click()

      assert render(view) =~ "No inventory entries yet"
    end

    test "opens form when New Entry is clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='inventory']")
      |> render_click()

      refute has_element?(view, "form#entry-form")

      view
      |> element("button", "New Entry")
      |> render_click()

      assert has_element?(view, "form#entry-form")
      assert has_element?(view, "select[name='entry[grocery_item_id]']")
      assert has_element?(view, "select[name='entry[storage_location_id]']")
    end

    test "creates new inventory entry", %{conn: conn, account: account, user: user} do
      item = create_grocery_item(account, user, %{name: "Eggs"})
      location = create_storage_location(account, user, %{name: "Fridge"})

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='inventory']")
      |> render_click()

      view
      |> element("button", "New Entry")
      |> render_click()

      view
      |> form("#entry-form",
        entry: %{
          grocery_item_id: item.id,
          storage_location_id: location.id,
          quantity: "12",
          unit: "count",
          status: "available"
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ "Eggs"
      assert html =~ "12 count"
      refute has_element?(view, "form#entry-form")
    end

    test "deletes inventory entry", %{conn: conn, account: account, user: user} do
      item = create_grocery_item(account, user, %{name: "Milk"})
      entry = create_inventory_entry(account, user, item, %{quantity: Decimal.new("1")})

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='inventory']")
      |> render_click()

      assert render(view) =~ "Milk"

      view
      |> element("button[phx-value-id='#{entry.id}']", "Delete")
      |> render_click()

      refute render(view) =~ "Milk"
    end

    test "displays status badges with correct styling", %{
      conn: conn,
      account: account,
      user: user
    } do
      item = create_grocery_item(account, user, %{name: "Test Item"})

      create_inventory_entry(account, user, item, %{
        quantity: Decimal.new("1"),
        status: :available
      })

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='inventory']")
      |> render_click()

      assert render(view) =~ "available"
    end
  end

  describe "Categories tab" do
    test "displays existing categories", %{conn: conn, account: account, user: user} do
      category1 = create_category(account, user, %{name: "Dairy", icon: "milk"})
      category2 = create_category(account, user, %{name: "Produce", icon: "apple"})

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='categories']")
      |> render_click()

      html = render(view)
      assert html =~ "Dairy"
      assert html =~ "Icon: milk"
      assert html =~ "Produce"
      assert html =~ "Icon: apple"
    end

    test "shows empty state when no categories exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='categories']")
      |> render_click()

      assert render(view) =~ "No categories yet"
    end

    test "opens form when New Category is clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='categories']")
      |> render_click()

      refute has_element?(view, "form#category-form")

      view
      |> element("button", "New Category")
      |> render_click()

      assert has_element?(view, "form#category-form")
      assert has_element?(view, "input[name='category[name]']")
    end

    test "creates new category", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='categories']")
      |> render_click()

      view
      |> element("button", "New Category")
      |> render_click()

      view
      |> form("#category-form",
        category: %{
          name: "Beverages",
          icon: "drink",
          sort_order: 5
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ "Beverages"
      assert html =~ "Icon: drink"
      refute has_element?(view, "form#category-form")
    end

    test "deletes category", %{conn: conn, account: account, user: user} do
      category = create_category(account, user, %{name: "Old Category"})

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='categories']")
      |> render_click()

      assert render(view) =~ "Old Category"

      view
      |> element("button[phx-value-id='#{category.id}']", "Delete")
      |> render_click()

      refute render(view) =~ "Old Category"
    end
  end

  describe "Storage Locations tab" do
    test "displays existing storage locations", %{conn: conn, account: account, user: user} do
      location1 =
        create_storage_location(account, user, %{name: "Fridge", temperature_zone: :cold})

      location2 =
        create_storage_location(account, user, %{name: "Pantry", temperature_zone: :room_temp})

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='locations']")
      |> render_click()

      html = render(view)
      assert html =~ "Fridge"
      assert html =~ "Temperature: cold"
      assert html =~ "Pantry"
      assert html =~ "Temperature: room_temp"
    end

    test "shows empty state when no locations exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='locations']")
      |> render_click()

      assert render(view) =~ "No storage locations yet"
    end

    test "opens form when New Location is clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='locations']")
      |> render_click()

      refute has_element?(view, "form#location-form")

      view
      |> element("button", "New Location")
      |> render_click()

      assert has_element?(view, "form#location-form")
      assert has_element?(view, "input[name='location[name]']")
      assert has_element?(view, "select[name='location[temperature_zone]']")
    end

    test "creates new storage location", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='locations']")
      |> render_click()

      view
      |> element("button", "New Location")
      |> render_click()

      view
      |> form("#location-form",
        location: %{
          name: "Freezer",
          temperature_zone: "frozen"
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ "Freezer"
      assert html =~ "Temperature: frozen"
      refute has_element?(view, "form#location-form")
    end

    test "deletes storage location", %{conn: conn, account: account, user: user} do
      location = create_storage_location(account, user, %{name: "Old Location"})

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='locations']")
      |> render_click()

      assert render(view) =~ "Old Location"

      view
      |> element("button[phx-value-id='#{location.id}']", "Delete")
      |> render_click()

      refute render(view) =~ "Old Location"
    end
  end

  describe "multi-tenancy" do
    test "only shows items from current account", %{conn: conn, account: account, user: user} do
      other_account = create_account()
      other_user = create_user(other_account)

      create_grocery_item(account, user, %{name: "My Item"})
      create_grocery_item(other_account, other_user, %{name: "Other Item"})

      {:ok, _view, html} = live(conn, "/inventory")

      assert html =~ "My Item"
      refute html =~ "Other Item"
    end

    test "only shows categories from current account", %{conn: conn, account: account, user: user} do
      other_account = create_account()
      other_user = create_user(other_account)

      create_category(account, user, %{name: "My Category"})
      create_category(other_account, other_user, %{name: "Other Category"})

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button[phx-value-tab='categories']")
      |> render_click()

      html = render(view)
      assert html =~ "My Category"
      refute html =~ "Other Category"
    end
  end

  describe "form state management" do
    test "form state resets when switching tabs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button", "New Item")
      |> render_click()

      assert has_element?(view, "form#item-form")

      view
      |> element("button[phx-value-tab='categories']")
      |> render_click()

      refute has_element?(view, "form#item-form")
    end

    test "canceling form resets state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button", "New Item")
      |> render_click()

      view
      |> element("button", "Cancel")
      |> render_click()

      refute has_element?(view, "form#item-form")

      view
      |> element("button", "New Item")
      |> render_click()

      assert has_element?(view, "form#item-form")
    end
  end
end
