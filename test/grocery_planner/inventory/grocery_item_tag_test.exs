defmodule GroceryPlanner.Inventory.GroceryItemTagTest do
  use GroceryPlanner.DataCase
  alias GroceryPlanner.Inventory

  describe "grocery_item_tag creation" do
    test "creates a tag with valid attributes" do
      {account, _user} = create_account_and_user()

      assert {:ok, tag} =
               Inventory.create_grocery_item_tag(
                 account.id,
                 %{
                   name: "Vegetable",
                   color: "#10B981",
                   description: "All vegetables"
                 },
                 authorize?: false,
                 tenant: account.id
               )

      assert tag.name == "Vegetable"
      assert tag.color == "#10B981"
      assert tag.description == "All vegetables"
      assert tag.account_id == account.id
    end

    test "uses default color if not provided" do
      {account, _user} = create_account_and_user()

      assert {:ok, tag} =
               Inventory.create_grocery_item_tag(
                 account.id,
                 %{
                   name: "Fruit"
                 },
                 authorize?: false,
                 tenant: account.id
               )

      assert tag.color == "#3B82F6"
    end

    test "requires name" do
      {account, _user} = create_account_and_user()

      assert {:error, %Ash.Error.Invalid{}} =
               Inventory.create_grocery_item_tag(
                 account.id,
                 %{
                   color: "#10B981"
                 },
                 authorize?: false,
                 tenant: account.id
               )
    end

    test "enforces unique name per account" do
      {account, _user} = create_account_and_user()

      assert {:ok, _tag1} =
               Inventory.create_grocery_item_tag(
                 account.id,
                 %{
                   name: "Vegetable"
                 },
                 authorize?: false,
                 tenant: account.id
               )

      assert {:error, %Ash.Error.Invalid{}} =
               Inventory.create_grocery_item_tag(
                 account.id,
                 %{
                   name: "Vegetable"
                 },
                 authorize?: false,
                 tenant: account.id
               )
    end

    test "allows same tag name for different accounts" do
      {account1, _user1} = create_account_and_user()
      {account2, _user2} = create_account_and_user()

      assert {:ok, tag1} =
               Inventory.create_grocery_item_tag(
                 account1.id,
                 %{
                   name: "Vegetable"
                 },
                 authorize?: false,
                 tenant: account1.id
               )

      assert {:ok, tag2} =
               Inventory.create_grocery_item_tag(
                 account2.id,
                 %{
                   name: "Vegetable"
                 },
                 authorize?: false,
                 tenant: account2.id
               )

      assert tag1.account_id != tag2.account_id
      assert tag1.name == tag2.name
    end
  end

  describe "grocery_item_tag updates" do
    test "updates tag attributes" do
      {account, _user} = create_account_and_user()

      {:ok, tag} =
        Inventory.create_grocery_item_tag(
          account.id,
          %{
            name: "Vegetable",
            color: "#10B981"
          },
          authorize?: false,
          tenant: account.id
        )

      assert {:ok, updated_tag} =
               Inventory.update_grocery_item_tag(
                 tag,
                 %{
                   name: "Veggie",
                   color: "#22C55E"
                 },
                 authorize?: false
               )

      assert updated_tag.name == "Veggie"
      assert updated_tag.color == "#22C55E"
    end
  end

  describe "grocery_item_tag listing" do
    test "lists all tags for an account" do
      {account, _user} = create_account_and_user()

      {:ok, _tag1} =
        Inventory.create_grocery_item_tag(account.id, %{name: "Vegetable"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, _tag2} =
        Inventory.create_grocery_item_tag(account.id, %{name: "Fruit"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, _tag3} =
        Inventory.create_grocery_item_tag(account.id, %{name: "Grain"},
          authorize?: false,
          tenant: account.id
        )

      tags = Inventory.list_grocery_item_tags!(authorize?: false, tenant: account.id)

      assert length(tags) == 3
      tag_names = Enum.map(tags, & &1.name) |> Enum.sort()
      assert tag_names == ["Fruit", "Grain", "Vegetable"]
    end

    test "does not list tags from other accounts" do
      {account1, _user1} = create_account_and_user()
      {account2, _user2} = create_account_and_user()

      {:ok, _tag1} =
        Inventory.create_grocery_item_tag(account1.id, %{name: "Vegetable"},
          authorize?: false,
          tenant: account1.id
        )

      {:ok, _tag2} =
        Inventory.create_grocery_item_tag(account2.id, %{name: "Fruit"},
          authorize?: false,
          tenant: account2.id
        )

      tags = Inventory.list_grocery_item_tags!(authorize?: false, tenant: account1.id)

      assert length(tags) == 1
      assert List.first(tags).name == "Vegetable"
    end
  end

  describe "grocery item tagging" do
    test "tags a grocery item" do
      {account, user} = create_account_and_user()

      item = create_grocery_item(account, user, %{name: "Carrot"})

      {:ok, tag} =
        Inventory.create_grocery_item_tag(account.id, %{name: "Vegetable"},
          authorize?: false,
          tenant: account.id
        )

      assert {:ok, tagging} =
               Inventory.create_grocery_item_tagging(
                 %{
                   grocery_item_id: item.id,
                   tag_id: tag.id
                 },
                 authorize?: false
               )

      assert tagging.grocery_item_id == item.id
      assert tagging.tag_id == tag.id
    end

    test "loads tags relationship on grocery item" do
      {account, user} = create_account_and_user()

      item = create_grocery_item(account, user, %{name: "Carrot"})

      {:ok, veg_tag} =
        Inventory.create_grocery_item_tag(account.id, %{name: "Vegetable"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, root_tag} =
        Inventory.create_grocery_item_tag(account.id, %{name: "Root Vegetable"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, _tagging1} =
        Inventory.create_grocery_item_tagging(
          %{
            grocery_item_id: item.id,
            tag_id: veg_tag.id
          },
          authorize?: false
        )

      {:ok, _tagging2} =
        Inventory.create_grocery_item_tagging(
          %{
            grocery_item_id: item.id,
            tag_id: root_tag.id
          },
          authorize?: false
        )

      item_with_tags = Ash.load!(item, :tags, authorize?: false)

      assert length(item_with_tags.tags) == 2
      tag_names = Enum.map(item_with_tags.tags, & &1.name) |> Enum.sort()
      assert tag_names == ["Root Vegetable", "Vegetable"]
    end

    test "loads grocery_items relationship on tag" do
      {account, user} = create_account_and_user()

      item1 = create_grocery_item(account, user, %{name: "Carrot"})
      item2 = create_grocery_item(account, user, %{name: "Potato"})

      {:ok, veg_tag} =
        Inventory.create_grocery_item_tag(account.id, %{name: "Vegetable"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, _tagging1} =
        Inventory.create_grocery_item_tagging(
          %{
            grocery_item_id: item1.id,
            tag_id: veg_tag.id
          },
          authorize?: false
        )

      {:ok, _tagging2} =
        Inventory.create_grocery_item_tagging(
          %{
            grocery_item_id: item2.id,
            tag_id: veg_tag.id
          },
          authorize?: false
        )

      tag_with_items = Ash.load!(veg_tag, :grocery_items, authorize?: false)

      assert length(tag_with_items.grocery_items) == 2
      item_names = Enum.map(tag_with_items.grocery_items, & &1.name) |> Enum.sort()
      assert item_names == ["Carrot", "Potato"]
    end

    test "prevents duplicate taggings" do
      {account, user} = create_account_and_user()

      item = create_grocery_item(account, user, %{name: "Carrot"})

      {:ok, tag} =
        Inventory.create_grocery_item_tag(account.id, %{name: "Vegetable"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, _tagging1} =
        Inventory.create_grocery_item_tagging(
          %{
            grocery_item_id: item.id,
            tag_id: tag.id
          },
          authorize?: false
        )

      assert {:error, %Ash.Error.Invalid{}} =
               Inventory.create_grocery_item_tagging(
                 %{
                   grocery_item_id: item.id,
                   tag_id: tag.id
                 },
                 authorize?: false
               )
    end

    test "removes tag from grocery item" do
      {account, user} = create_account_and_user()

      item = create_grocery_item(account, user, %{name: "Carrot"})

      {:ok, tag} =
        Inventory.create_grocery_item_tag(account.id, %{name: "Vegetable"},
          authorize?: false,
          tenant: account.id
        )

      {:ok, tagging} =
        Inventory.create_grocery_item_tagging(
          %{
            grocery_item_id: item.id,
            tag_id: tag.id
          },
          authorize?: false
        )

      assert :ok = Inventory.destroy_grocery_item_tagging(tagging, authorize?: false)

      item_with_tags = Ash.load!(item, :tags, authorize?: false)
      assert length(item_with_tags.tags) == 0
    end
  end
end
