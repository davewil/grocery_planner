defmodule GroceryPlanner.Inventory.GroceryItemTagging do
  use Ash.Resource,
    domain: GroceryPlanner.Inventory,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "grocery_item_taggings"
    repo GroceryPlanner.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:grocery_item_id, :tag_id]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :grocery_item_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :tag_id, :uuid do
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
  end

  relationships do
    belongs_to :grocery_item, GroceryPlanner.Inventory.GroceryItem do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :tag, GroceryPlanner.Inventory.GroceryItemTag do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_grocery_item_tag, [:grocery_item_id, :tag_id]
  end
end
