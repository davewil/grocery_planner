defmodule GroceryPlannerWeb.InventoryLiveWasteTest do
  use GroceryPlannerWeb.ConnCase

  import Phoenix.LiveViewTest
  import GroceryPlanner.InventoryTestHelpers

  describe "Inventory Waste Tracking" do
    setup do
      {account, user} = create_account_and_user()
      grocery_item = create_grocery_item(account, user)
      storage_location = create_storage_location(account, user)

      entry =
        create_inventory_entry(account, user, grocery_item, %{
          storage_location_id: storage_location.id,
          purchase_price: Money.new(500, :USD)
        })

      conn =
        build_conn()
        |> init_test_session(%{
          user_id: user.id,
          account_id: account.id
        })

      %{conn: conn, account: account, user: user, entry: entry}
    end

    test "consume entry creates usage log and updates entry status", %{conn: conn, entry: entry} do
      {:ok, view, _html} = live(conn, ~p"/inventory?tab=inventory")

      view
      |> element("button[phx-click='consume_entry'][phx-value-id='#{entry.id}']")
      |> render_click()

      # assert_patch(view, ~p"/inventory?tab=inventory") # It might not patch if URL doesn't change, but it re-renders
      assert render(view) =~ "Item marked as consumed"

      # Verify UsageLog created
      assert {:ok, logs} =
               GroceryPlanner.Analytics.UsageLog.read(authorize?: false, tenant: entry.account_id)

      assert length(logs) == 1
      log = hd(logs)
      assert log.reason == :consumed
      assert log.grocery_item_id == entry.grocery_item_id
      assert log.quantity == entry.quantity

      # Verify Entry updated
      updated_entry =
        GroceryPlanner.Inventory.get_inventory_entry!(entry.id,
          authorize?: false,
          tenant: entry.account_id
        )

      assert updated_entry.status == :consumed
    end

    test "expire entry creates usage log and updates entry status", %{conn: conn, entry: entry} do
      {:ok, view, _html} = live(conn, ~p"/inventory?tab=inventory")

      view
      |> element("button[phx-click='expire_entry'][phx-value-id='#{entry.id}']")
      |> render_click()

      # assert_patch(view, ~p"/inventory?tab=inventory")
      assert render(view) =~ "Item marked as expired"

      # Verify UsageLog created
      assert {:ok, logs} =
               GroceryPlanner.Analytics.UsageLog.read(authorize?: false, tenant: entry.account_id)

      assert length(logs) == 1
      log = hd(logs)
      assert log.reason == :expired

      # Verify Entry updated
      updated_entry =
        GroceryPlanner.Inventory.get_inventory_entry!(entry.id,
          authorize?: false,
          tenant: entry.account_id
        )

      assert updated_entry.status == :expired
    end
  end
end
