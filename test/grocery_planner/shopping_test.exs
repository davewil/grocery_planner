defmodule GroceryPlanner.ShoppingTest do
  use GroceryPlanner.DataCase

  alias GroceryPlanner.Shopping
  alias GroceryPlanner.Shopping.ShoppingList
  alias GroceryPlanner.Shopping.ShoppingListItem

  import GroceryPlanner.InventoryTestHelpers

  setup do
    account = create_account()
    user = create_user(account)
    %{account: account, user: user}
  end

  describe "shopping lists" do
    test "create_shopping_list/2 creates a list", %{account: account, user: user} do
      assert {:ok, %ShoppingList{} = list} =
               Shopping.create_shopping_list(
                 account.id,
                 %{name: "Weekly Groceries"},
                 actor: user,
                 tenant: account.id
               )

      assert list.name == "Weekly Groceries"
      assert list.status == :active
      assert list.account_id == account.id
    end

    test "list_shopping_lists/1 returns lists", %{account: account, user: user} do
      {:ok, list1} =
        Shopping.create_shopping_list(
          account.id,
          %{name: "List 1"},
          actor: user,
          tenant: account.id
        )

      {:ok, list2} =
        Shopping.create_shopping_list(
          account.id,
          %{name: "List 2"},
          actor: user,
          tenant: account.id
        )

      {:ok, lists} =
        Shopping.list_shopping_lists(
          actor: user,
          tenant: account.id
        )

      assert length(lists) == 2
      assert Enum.any?(lists, &(&1.id == list1.id))
      assert Enum.any?(lists, &(&1.id == list2.id))
    end
  end

  describe "shopping list items" do
    setup %{account: account, user: user} do
      {:ok, list} =
        Shopping.create_shopping_list(
          account.id,
          %{name: "Weekly Groceries"},
          actor: user,
          tenant: account.id
        )

      %{list: list}
    end

    test "create_shopping_list_item/2 adds item to list", %{account: account, user: user, list: list} do
      assert {:ok, %ShoppingListItem{} = item} =
               Shopping.create_shopping_list_item(
                 account.id,
                 %{
                   shopping_list_id: list.id,
                   name: "Milk",
                   quantity: Decimal.new("2"),
                   unit: "gallons"
                 },
                 actor: user,
                 tenant: account.id
               )

      assert item.name == "Milk"
      assert Decimal.equal?(item.quantity, Decimal.new("2"))
      assert item.unit == "gallons"
      assert item.shopping_list_id == list.id
      assert item.checked == false
    end

    test "toggle_shopping_list_item_check/1 toggles checked status", %{
      account: account,
      user: user,
      list: list
    } do
      {:ok, item} =
        Shopping.create_shopping_list_item(
          account.id,
          %{
            shopping_list_id: list.id,
            name: "Eggs",
            quantity: Decimal.new("12")
          },
          actor: user,
          tenant: account.id
        )

      assert item.checked == false

      {:ok, updated_item} =
        Shopping.toggle_shopping_list_item_check(item, actor: user, tenant: account.id)

      assert updated_item.checked == true

      {:ok, updated_item_2} =
        Shopping.toggle_shopping_list_item_check(updated_item, actor: user, tenant: account.id)

      assert updated_item_2.checked == false
    end
  end
end
