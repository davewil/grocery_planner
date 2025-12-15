defmodule GroceryPlanner.Inventory.StorageLocationTest do
  use GroceryPlanner.DataCase, async: true

  alias GroceryPlanner.Inventory.StorageLocation

  describe "create/1" do
    setup do
      account = create_account()
      user = create_user(account)
      %{account: account, user: user}
    end

    test "creates a storage location with valid attributes", %{account: account, user: _user} do
      attrs = %{
        name: "Fridge",
        temperature_zone: :cold,
        account_id: account.id
      }

      assert {:ok, location} =
               StorageLocation
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create(authorize?: false, tenant: account.id)

      assert location.name == "Fridge"
      assert location.temperature_zone == :cold
      assert location.account_id == account.id
    end

    test "validates temperature_zone enum values", %{account: account, user: _user} do
      for zone <- [:frozen, :cold, :cool, :room_temp] do
        attrs = %{name: "Location #{zone}", temperature_zone: zone, account_id: account.id}

        assert {:ok, location} =
                 StorageLocation
                 |> Ash.Changeset.for_create(:create, attrs)
                 |> Ash.create(authorize?: false, tenant: account.id)

        assert location.temperature_zone == zone
      end
    end

    test "requires name", %{account: account, user: _user} do
      attrs = %{temperature_zone: :cold, account_id: account.id}

      assert {:error, %Ash.Error.Invalid{}} =
               StorageLocation
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create(authorize?: false, tenant: account.id)
    end

    test "enforces unique name per account", %{account: account, user: _user} do
      attrs = %{name: "Fridge", account_id: account.id}

      assert {:ok, _location1} =
               StorageLocation
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create(authorize?: false, tenant: account.id)

      assert {:error, %Ash.Error.Invalid{}} =
               StorageLocation
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create(authorize?: false, tenant: account.id)
    end
  end

  describe "read/0" do
    setup do
      account = create_account()
      user = create_user(account)
      %{account: account, user: user}
    end

    test "lists storage locations for account", %{account: account, user: user} do
      create_storage_location(account, user, %{name: "Fridge"})
      create_storage_location(account, user, %{name: "Freezer"})

      locations =
        GroceryPlanner.Inventory.list_storage_locations!(authorize?: false, tenant: account.id)

      assert length(locations) == 2
      assert Enum.any?(locations, &(&1.name == "Fridge"))
      assert Enum.any?(locations, &(&1.name == "Freezer"))
    end
  end

  describe "update/2" do
    setup do
      account = create_account()
      user = create_user(account)

      location =
        create_storage_location(account, user, %{name: "Fridge", temperature_zone: :cold})

      %{account: account, user: user, location: location}
    end

    test "updates storage location attributes", %{
      account: account,
      user: _user,
      location: location
    } do
      update_attrs = %{name: "Main Fridge", temperature_zone: :cool}

      assert {:ok, updated} =
               location
               |> Ash.Changeset.for_update(:update, update_attrs)
               |> Ash.update(authorize?: false, tenant: account.id)

      assert updated.name == "Main Fridge"
      assert updated.temperature_zone == :cool
    end
  end

  describe "destroy/1" do
    setup do
      account = create_account()
      user = create_user(account)
      location = create_storage_location(account, user, %{name: "Fridge"})

      %{account: account, user: user, location: location}
    end

    test "deletes a storage location", %{account: account, user: _user, location: location} do
      assert :ok = Ash.destroy(location, authorize?: false, tenant: account.id)

      locations =
        GroceryPlanner.Inventory.list_storage_locations!(authorize?: false, tenant: account.id)

      assert locations == []
    end
  end
end
