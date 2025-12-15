defmodule GroceryPlanner.Analytics.UsageLogTest do
  use GroceryPlanner.DataCase

  alias GroceryPlanner.Analytics.UsageLog
  import GroceryPlanner.InventoryTestHelpers

  describe "usage_logs" do
    test "creates a usage log" do
      {account, user} = create_account_and_user()
      item = create_grocery_item(account, user)

      attrs = %{
        quantity: Decimal.new("1.5"),
        unit: "kg",
        reason: :consumed,
        occurred_at: DateTime.utc_now(),
        cost: Money.new(100, :USD),
        grocery_item_id: item.id,
        account_id: account.id
      }

      assert {:ok, log} = UsageLog.create(attrs, authorize?: false, tenant: account.id)
      assert log.quantity == Decimal.new("1.5")
      assert log.reason == :consumed
      assert log.account_id == account.id
    end
  end
end
