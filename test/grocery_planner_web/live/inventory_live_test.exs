defmodule GroceryPlannerWeb.InventoryLiveTest do
  use GroceryPlannerWeb.ConnCase, async: true
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
      _item1 = create_grocery_item(account, user, %{name: "Milk", description: "Whole milk"})
      _item2 = create_grocery_item(account, user, %{name: "Bread", description: "Whole wheat"})

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
      _category1 = create_category(account, user, %{name: "Dairy", icon: "milk"})
      _category2 = create_category(account, user, %{name: "Produce", icon: "apple"})

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
      _location1 =
        create_storage_location(account, user, %{name: "Fridge", temperature_zone: :cold})

      _location2 =
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

  describe "tag filtering" do
    test "toggle_tag_filter filters grocery items by tag", %{conn: conn, account: account} do
      # Create a tag
      {:ok, tag} =
        GroceryPlanner.Inventory.create_grocery_item_tag(
          account.id,
          %{name: "Protein", color: "#EF4444"},
          authorize?: false,
          tenant: account.id
        )

      # Create two items, one with the tag
      {:ok, item_with_tag} =
        GroceryPlanner.Inventory.create_grocery_item(
          account.id,
          %{name: "Chicken Breast"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, _item_without_tag} =
        GroceryPlanner.Inventory.create_grocery_item(
          account.id,
          %{name: "Milk"},
          authorize?: false,
          tenant: account.id
        )

      # Associate tag with item
      GroceryPlanner.Inventory.create_grocery_item_tagging(
        %{grocery_item_id: item_with_tag.id, tag_id: tag.id},
        authorize?: false
      )

      {:ok, view, _html} = live(conn, "/inventory")

      # Both items should be visible initially
      assert has_element?(view, "div", "Chicken Breast")
      assert has_element?(view, "div", "Milk")

      # Click the tag filter
      view
      |> element("button[phx-click='toggle_tag_filter'][phx-value-tag-id='#{tag.id}']")
      |> render_click()

      # Only tagged item should be visible
      assert has_element?(view, "div", "Chicken Breast")
      refute has_element?(view, "div", "Milk")
    end

    test "clear_tag_filters clears all tag filters", %{conn: conn, account: account} do
      {:ok, tag} =
        GroceryPlanner.Inventory.create_grocery_item_tag(
          account.id,
          %{name: "Vegetable", color: "#10B981"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, _item} =
        GroceryPlanner.Inventory.create_grocery_item(
          account.id,
          %{name: "Test Item"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, view, _html} = live(conn, "/inventory")

      # Apply tag filter
      view
      |> element("button[phx-click='toggle_tag_filter'][phx-value-tag-id='#{tag.id}']")
      |> render_click()

      # Clear filters
      view
      |> element("button[phx-click='clear_tag_filters']")
      |> render_click()

      # Item should be visible again
      assert has_element?(view, "div", "Test Item")
    end
  end

  describe "editing grocery items" do
    test "edit_item opens form with item data", %{conn: conn, account: account} do
      {:ok, item} =
        GroceryPlanner.Inventory.create_grocery_item(
          account.id,
          %{name: "Original Name", description: "Original desc"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, view, _html} = live(conn, "/inventory")

      # Click edit button
      view
      |> element("button[phx-click='edit_item'][phx-value-id='#{item.id}']")
      |> render_click()

      # Form should be shown with existing values
      assert has_element?(view, "form#item-form")

      # The form should have the item's current values
      html = render(view)
      assert html =~ "Original Name"
    end

    test "edit_item updates existing item", %{conn: conn, account: account} do
      {:ok, item} =
        GroceryPlanner.Inventory.create_grocery_item(
          account.id,
          %{name: "Original Name"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, view, _html} = live(conn, "/inventory")

      # Click edit button
      view
      |> element("button[phx-click='edit_item'][phx-value-id='#{item.id}']")
      |> render_click()

      # Submit the form with new name
      view
      |> form("#item-form", item: %{name: "Updated Name"})
      |> render_submit()

      # Updated name should appear
      assert has_element?(view, "div", "Updated Name")
    end
  end

  describe "tag management" do
    test "manage_tags opens tag modal for an item", %{conn: conn, account: account} do
      {:ok, item} =
        GroceryPlanner.Inventory.create_grocery_item(
          account.id,
          %{name: "Test Item"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, _tag} =
        GroceryPlanner.Inventory.create_grocery_item_tag(
          account.id,
          %{name: "Test Tag", color: "#FF0000"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, view, _html} = live(conn, "/inventory")

      # Click manage tags button
      view
      |> element("button[phx-click='manage_tags'][phx-value-id='#{item.id}']")
      |> render_click()

      # Tag management modal should be shown
      assert has_element?(view, "div", "Manage Tags for")
      assert has_element?(view, "div", "Test Tag")
    end

    test "add_tag_to_item associates tag with item", %{conn: conn, account: account} do
      {:ok, item} =
        GroceryPlanner.Inventory.create_grocery_item(
          account.id,
          %{name: "Test Item"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, tag} =
        GroceryPlanner.Inventory.create_grocery_item_tag(
          account.id,
          %{name: "Add Me", color: "#00FF00"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, view, _html} = live(conn, "/inventory")

      # Open tag management
      view
      |> element("button[phx-click='manage_tags'][phx-value-id='#{item.id}']")
      |> render_click()

      # Add tag to item
      view
      |> element("button[phx-click='add_tag_to_item'][phx-value-tag-id='#{tag.id}']")
      |> render_click()

      # Tag should now show Remove button instead of Add
      assert has_element?(
               view,
               "button[phx-click='remove_tag_from_item'][phx-value-tag-id='#{tag.id}']"
             )
    end
  end

  describe "tag selection in edit form" do
    test "can select and save tags when editing an item", %{conn: conn, account: account} do
      {:ok, item} =
        GroceryPlanner.Inventory.create_grocery_item(
          account.id,
          %{name: "Test Item"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, tag} =
        GroceryPlanner.Inventory.create_grocery_item_tag(
          account.id,
          %{name: "TestTag", color: "#FF5500"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, view, _html} = live(conn, "/inventory")

      # Click edit button
      view
      |> element("button[phx-click='edit_item'][phx-value-id='#{item.id}']")
      |> render_click()

      # Tag selection should be visible
      assert has_element?(view, "label", "TestTag")

      # Toggle the tag
      view
      |> element("input[phx-click='toggle_form_tag'][phx-value-tag-id='#{tag.id}']")
      |> render_click()

      # Save the item
      view
      |> form("#item-form", item: %{name: "Test Item"})
      |> render_submit()

      # Verify the tag was saved - reload item and check
      {:ok, updated_item} =
        GroceryPlanner.Inventory.get_grocery_item(item.id,
          authorize?: false,
          tenant: account.id,
          load: [:tags]
        )

      assert length(updated_item.tags) == 1
      assert hd(updated_item.tags).name == "TestTag"
    end
  end
end
