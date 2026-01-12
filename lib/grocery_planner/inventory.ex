defmodule GroceryPlanner.Inventory do
  @moduledoc false
  use Ash.Domain,
    extensions: [AshJsonApi.Domain]

  json_api do
    prefix "/api/json"
  end

  resources do
    resource GroceryPlanner.Inventory.Category do
      define :create_category, action: :create, args: [:account_id]
      define :list_categories, action: :read
      define :get_category, action: :read, get_by: [:id]
      define :update_category, action: :update
      define :destroy_category, action: :destroy
    end

    resource GroceryPlanner.Inventory.StorageLocation do
      define :create_storage_location, action: :create, args: [:account_id]
      define :list_storage_locations, action: :read
      define :get_storage_location, action: :read, get_by: [:id]
      define :update_storage_location, action: :update
      define :destroy_storage_location, action: :destroy
    end

    resource GroceryPlanner.Inventory.GroceryItem do
      define :create_grocery_item, action: :create, args: [:account_id]
      define :list_grocery_items, action: :read
      define :get_grocery_item, action: :read, get_by: [:id]
      define :update_grocery_item, action: :update
      define :destroy_grocery_item, action: :destroy
    end

    resource GroceryPlanner.Inventory.InventoryEntry do
      define :create_inventory_entry, action: :create, args: [:account_id, :grocery_item_id]
      define :list_inventory_entries, action: :read
      define :get_inventory_entry, action: :read, get_by: [:id]
      define :update_inventory_entry, action: :update
      define :destroy_inventory_entry, action: :destroy
    end

    resource GroceryPlanner.Inventory.GroceryItemTag do
      define :create_grocery_item_tag, action: :create, args: [:account_id]
      define :list_grocery_item_tags, action: :read
      define :get_grocery_item_tag, action: :read, get_by: [:id]
      define :update_grocery_item_tag, action: :update
      define :destroy_grocery_item_tag, action: :destroy
    end

    resource GroceryPlanner.Inventory.GroceryItemTagging do
      define :create_grocery_item_tagging, action: :create
      define :list_grocery_item_taggings, action: :read
      define :destroy_grocery_item_tagging, action: :destroy
    end

    resource GroceryPlanner.Inventory.Receipt do
      define :create_receipt, action: :create, args: [:account_id]
      define :list_receipts, action: :read
      define :get_receipt, action: :read, get_by: [:id]
      define :update_receipt, action: :update
      define :destroy_receipt, action: :destroy
    end
  end
end
