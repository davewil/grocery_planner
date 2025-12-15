defmodule GroceryPlanner.Notifications.ExpirationAlertsTest do
  use GroceryPlanner.DataCase, async: true

  alias GroceryPlanner.Notifications.ExpirationAlerts
  alias GroceryPlanner.InventoryTestHelpers

  describe "expiration alerts" do
    setup do
      {account, user} = InventoryTestHelpers.create_account_and_user()
      category = InventoryTestHelpers.create_category(account, user)
      location = InventoryTestHelpers.create_storage_location(account, user)
      item = InventoryTestHelpers.create_grocery_item(account, user, %{category_id: category.id})

      %{account: account, user: user, item: item, location: location}
    end

    test "get_expiring_items/3 categorizes items correctly", %{
      account: account,
      user: user,
      item: item,
      location: location
    } do
      today = Date.utc_today()

      # Expired item (yesterday)
      InventoryTestHelpers.create_inventory_entry(account, user, item, %{
        storage_location_id: location.id,
        use_by_date: Date.add(today, -1),
        quantity: Decimal.new("1")
      })

      # Expiring today
      InventoryTestHelpers.create_inventory_entry(account, user, item, %{
        storage_location_id: location.id,
        use_by_date: today,
        quantity: Decimal.new("1")
      })

      # Expiring tomorrow
      InventoryTestHelpers.create_inventory_entry(account, user, item, %{
        storage_location_id: location.id,
        use_by_date: Date.add(today, 1),
        quantity: Decimal.new("1")
      })

      # Expiring this week (3 days)
      InventoryTestHelpers.create_inventory_entry(account, user, item, %{
        storage_location_id: location.id,
        use_by_date: Date.add(today, 3),
        quantity: Decimal.new("1")
      })

      # Expiring soon (5 days)
      InventoryTestHelpers.create_inventory_entry(account, user, item, %{
        storage_location_id: location.id,
        use_by_date: Date.add(today, 5),
        quantity: Decimal.new("1")
      })

      # Not expiring soon (10 days)
      InventoryTestHelpers.create_inventory_entry(account, user, item, %{
        storage_location_id: location.id,
        use_by_date: Date.add(today, 10),
        quantity: Decimal.new("1")
      })

      {:ok, alerts} = ExpirationAlerts.get_expiring_items(account.id, user, days_threshold: 7)

      assert length(alerts.expired) == 1
      assert length(alerts.today) == 1
      assert length(alerts.tomorrow) == 1
      assert length(alerts.this_week) == 1
      assert length(alerts.soon) == 1
      assert alerts.total_count == 5
    end

    test "get_expiring_summary/3 returns correct counts", %{
      account: account,
      user: user,
      item: item,
      location: location
    } do
      today = Date.utc_today()

      # Create one of each category
      InventoryTestHelpers.create_inventory_entry(account, user, item, %{
        storage_location_id: location.id,
        use_by_date: Date.add(today, -1)
      })

      InventoryTestHelpers.create_inventory_entry(account, user, item, %{
        storage_location_id: location.id,
        use_by_date: today
      })

      {:ok, summary} = ExpirationAlerts.get_expiring_summary(account.id, user)

      assert summary.expired_count == 1
      assert summary.today_count == 1
      assert summary.total_count == 2
    end

    test "has_critical_alerts?/2 returns true only for expired or today", %{
      account: account,
      user: user,
      item: item,
      location: location
    } do
      today = Date.utc_today()

      # Initially false
      refute ExpirationAlerts.has_critical_alerts?(account.id, user)

      # Add item expiring tomorrow (not critical)
      InventoryTestHelpers.create_inventory_entry(account, user, item, %{
        storage_location_id: location.id,
        use_by_date: Date.add(today, 1)
      })

      refute ExpirationAlerts.has_critical_alerts?(account.id, user)

      # Add item expiring today (critical)
      InventoryTestHelpers.create_inventory_entry(account, user, item, %{
        storage_location_id: location.id,
        use_by_date: today
      })

      assert ExpirationAlerts.has_critical_alerts?(account.id, user)
    end

    test "respects days_threshold option", %{
      account: account,
      user: user,
      item: item,
      location: location
    } do
      today = Date.utc_today()

      # Expiring in 5 days
      InventoryTestHelpers.create_inventory_entry(account, user, item, %{
        storage_location_id: location.id,
        use_by_date: Date.add(today, 5)
      })

      # Default threshold is 7, so should be included
      {:ok, alerts} = ExpirationAlerts.get_expiring_items(account.id, user)
      assert alerts.total_count == 1

      # Threshold of 3, should NOT be included
      {:ok, alerts} = ExpirationAlerts.get_expiring_items(account.id, user, days_threshold: 3)
      assert alerts.total_count == 0
    end
  end
end
