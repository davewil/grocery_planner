defmodule GroceryPlanner.InventorySimpleTest do
  use GroceryPlanner.DataCase, async: true

  alias GroceryPlanner.Inventory.{Category, StorageLocation, GroceryItem, InventoryEntry}

  describe "Phase 2 inventory resources" do
    setup do
      account = create_account()
      user = create_user(account)
      %{account: account, user: user}
    end

    test "Category CRUD operations work", %{account: account, user: _user} do
      {:ok, category} =
        Category
        |> Ash.Changeset.for_create(
          :create,
          %{
            account_id: account.id,
            name: "Dairy",
            icon: "milk-icon",
            sort_order: 1
          },
          tenant: account.id
        )
        |> Ash.create(authorize?: false)

      assert category.name == "Dairy"
      assert category.icon == "milk-icon"
      assert category.account_id == account.id

      {:ok, categories} = Ash.read(Category, authorize?: false, tenant: account.id)
      assert length(categories) == 1

      {:ok, updated} =
        category
        |> Ash.Changeset.for_update(:update, %{name: "Dairy Products"})
        |> Ash.update(authorize?: false, tenant: account.id)

      assert updated.name == "Dairy Products"

      :ok = Ash.destroy(category, authorize?: false, tenant: account.id)

      {:ok, categories} = Ash.read(Category, authorize?: false, tenant: account.id)
      assert categories == []
    end

    test "StorageLocation CRUD operations work", %{account: account, user: _user} do
      {:ok, location} =
        StorageLocation
        |> Ash.Changeset.for_create(
          :create,
          %{
            account_id: account.id,
            name: "Fridge",
            temperature_zone: :cold
          },
          tenant: account.id
        )
        |> Ash.create(authorize?: false)

      assert location.name == "Fridge"
      assert location.temperature_zone == :cold

      {:ok, locations} = Ash.read(StorageLocation, authorize?: false, tenant: account.id)
      assert length(locations) == 1
    end

    test "GroceryItem CRUD operations work", %{account: account, user: _user} do
      {:ok, category} =
        Category
        |> Ash.Changeset.for_create(
          :create,
          %{
            account_id: account.id,
            name: "Dairy"
          },
          tenant: account.id
        )
        |> Ash.create(authorize?: false)

      {:ok, item} =
        GroceryItem
        |> Ash.Changeset.for_create(
          :create,
          %{
            account_id: account.id,
            name: "Milk",
            description: "Whole milk",
            default_unit: "gallon",
            category_id: category.id
          },
          tenant: account.id
        )
        |> Ash.create(authorize?: false)

      assert item.name == "Milk"
      assert item.description == "Whole milk"
      assert item.category_id == category.id

      {:ok, items} = Ash.read(GroceryItem, authorize?: false, tenant: account.id)
      assert length(items) == 1
    end

    test "InventoryEntry CRUD operations and calculations work", %{account: account, user: _user} do
      {:ok, item} =
        GroceryItem
        |> Ash.Changeset.for_create(
          :create,
          %{
            account_id: account.id,
            name: "Milk"
          },
          tenant: account.id
        )
        |> Ash.create(authorize?: false)

      today = Date.utc_today()
      future_date = Date.add(today, 5)

      {:ok, entry} =
        InventoryEntry
        |> Ash.Changeset.for_create(
          :create,
          %{
            account_id: account.id,
            grocery_item_id: item.id,
            quantity: Decimal.new("2.5"),
            unit: "gallon",
            status: :available,
            use_by_date: future_date
          },
          tenant: account.id
        )
        |> Ash.create(authorize?: false)

      assert Decimal.equal?(entry.quantity, Decimal.new("2.5"))
      assert entry.unit == "gallon"
      assert entry.status == :available

      entry_with_calcs =
        GroceryPlanner.Inventory.get_inventory_entry!(entry.id,
          authorize?: false,
          tenant: account.id,
          load: [:days_until_expiry, :is_expiring_soon, :is_expired]
        )

      assert entry_with_calcs.days_until_expiry == 5
      assert entry_with_calcs.is_expiring_soon == true
      assert entry_with_calcs.is_expired == false

      entries =
        GroceryPlanner.Inventory.list_inventory_entries!(authorize?: false, tenant: account.id)

      assert length(entries) == 1
    end

    test "multitenancy works correctly", %{} do
      account1 = create_account()
      account2 = create_account()
      _user1 = create_user(account1)
      _user2 = create_user(account2)

      {:ok, _cat1} =
        Category
        |> Ash.Changeset.for_create(:create, %{account_id: account1.id, name: "Dairy"},
          tenant: account1.id
        )
        |> Ash.create(authorize?: false)

      {:ok, _cat2} =
        Category
        |> Ash.Changeset.for_create(:create, %{account_id: account2.id, name: "Produce"},
          tenant: account2.id
        )
        |> Ash.create(authorize?: false)

      {:ok, account1_cats} = Ash.read(Category, authorize?: false, tenant: account1.id)
      {:ok, account2_cats} = Ash.read(Category, authorize?: false, tenant: account2.id)

      assert length(account1_cats) == 1
      assert length(account2_cats) == 1
      assert hd(account1_cats).name == "Dairy"
      assert hd(account2_cats).name == "Produce"
    end
  end
end
