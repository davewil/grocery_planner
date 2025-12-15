defmodule GroceryPlanner.Inventory.CategoryTest do
  use GroceryPlanner.DataCase, async: true

  describe "create/1" do
    setup do
      account = create_account()
      user = create_user(account)
      %{account: account, user: user}
    end

    test "creates a category with valid attributes", %{account: account} do
      attrs = %{
        name: "Dairy",
        icon: "milk-icon",
        sort_order: 1
      }

      category =
        GroceryPlanner.Inventory.create_category!(
          account.id,
          attrs,
          authorize?: false,
          tenant: account.id
        )

      assert category.name == "Dairy"
      assert category.icon == "milk-icon"
      assert category.sort_order == 1
      assert category.account_id == account.id
    end

    test "creates a category with default sort_order", %{account: account} do
      attrs = %{name: "Produce"}

      category =
        GroceryPlanner.Inventory.create_category!(
          account.id,
          attrs,
          authorize?: false,
          tenant: account.id
        )

      assert category.sort_order == 0
    end

    test "requires name", %{account: account} do
      attrs = %{icon: "icon"}

      assert_raise Ash.Error.Invalid, fn ->
        GroceryPlanner.Inventory.create_category!(
          account.id,
          attrs,
          authorize?: false,
          tenant: account.id
        )
      end
    end

    test "enforces unique name per account", %{account: account} do
      attrs = %{name: "Dairy"}

      _category1 =
        GroceryPlanner.Inventory.create_category!(
          account.id,
          attrs,
          authorize?: false,
          tenant: account.id
        )

      assert_raise Ash.Error.Invalid, fn ->
        GroceryPlanner.Inventory.create_category!(
          account.id,
          attrs,
          authorize?: false,
          tenant: account.id
        )
      end
    end

    test "allows same name in different accounts" do
      account1 = create_account()
      account2 = create_account()
      _user1 = create_user(account1)
      _user2 = create_user(account2)

      attrs = %{name: "Dairy"}

      category1 =
        GroceryPlanner.Inventory.create_category!(
          account1.id,
          attrs,
          authorize?: false,
          tenant: account1.id
        )

      category2 =
        GroceryPlanner.Inventory.create_category!(
          account2.id,
          attrs,
          authorize?: false,
          tenant: account2.id
        )

      assert category1.name == category2.name
      assert category1.account_id != category2.account_id
    end
  end

  describe "read/0" do
    setup do
      account = create_account()
      user = create_user(account)
      %{account: account, user: user}
    end

    test "lists categories for account", %{account: account, user: user} do
      create_category(account, user, %{name: "Dairy"})
      create_category(account, user, %{name: "Produce"})

      categories =
        GroceryPlanner.Inventory.list_categories!(authorize?: false, tenant: account.id)

      assert length(categories) == 2
      assert Enum.any?(categories, &(&1.name == "Dairy"))
      assert Enum.any?(categories, &(&1.name == "Produce"))
    end

    test "does not list categories from other accounts" do
      account1 = create_account()
      account2 = create_account()
      user1 = create_user(account1)
      _user2 = create_user(account2)

      create_category(account1, user1, %{name: "Dairy"})

      categories =
        GroceryPlanner.Inventory.list_categories!(authorize?: false, tenant: account2.id)

      assert categories == []
    end
  end

  describe "update/2" do
    setup do
      account = create_account()
      user = create_user(account)
      category = create_category(account, user, %{name: "Dairy", icon: "old-icon", sort_order: 1})

      %{account: account, user: user, category: category}
    end

    test "updates category attributes", %{account: account, category: category} do
      update_attrs = %{name: "Dairy Products", icon: "new-icon", sort_order: 2}

      updated =
        GroceryPlanner.Inventory.update_category!(
          category,
          update_attrs,
          authorize?: false,
          tenant: account.id
        )

      assert updated.name == "Dairy Products"
      assert updated.icon == "new-icon"
      assert updated.sort_order == 2
    end

    test "enforces unique name constraint on update", %{
      account: account,
      user: user,
      category: category
    } do
      create_category(account, user, %{name: "Produce"})

      update_attrs = %{name: "Produce"}

      assert_raise Ash.Error.Invalid, fn ->
        GroceryPlanner.Inventory.update_category!(
          category,
          update_attrs,
          authorize?: false,
          tenant: account.id
        )
      end
    end
  end

  describe "destroy/1" do
    setup do
      account = create_account()
      user = create_user(account)
      category = create_category(account, user, %{name: "Dairy"})

      %{account: account, user: user, category: category}
    end

    test "deletes a category", %{account: account, category: category} do
      :ok =
        GroceryPlanner.Inventory.destroy_category!(category,
          authorize?: false,
          tenant: account.id
        )

      categories =
        GroceryPlanner.Inventory.list_categories!(authorize?: false, tenant: account.id)

      assert categories == []
    end
  end
end
