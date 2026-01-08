defmodule GroceryPlanner.Inventory.GroceryItem do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    table "grocery_items"
    repo GroceryPlanner.Repo
  end

  json_api do
    type "grocery_item"

    routes do
      base("/grocery_items")
      get(:read)
      index :read
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  code_interface do
    define :create
    define :read
    define :by_id, action: :read, get_by: [:id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :default_unit, :barcode, :category_id, :is_waste_risk]
      argument :account_id, :uuid, allow_nil?: false

      change set_attribute(:account_id, arg(:account_id))
    end

    update :update do
      accept [:name, :description, :default_unit, :barcode, :category_id, :is_waste_risk]
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action_type(:create) do
      # For create, we rely on multitenancy - the tenant is set by the ApiAuth plug
      # and is the account_id. If the user can authenticate and set the tenant,
      # they can create items in that tenant.
      authorize_if always()
    end

    policy action_type([:update, :destroy]) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end
  end

  multitenancy do
    strategy :attribute
    attribute :account_id
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :default_unit, :string do
      public? true
    end

    attribute :barcode, :string do
      public? true
    end

    attribute :account_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :category_id, :uuid do
      public? true
    end

    attribute :is_waste_risk, :boolean do
      default false
      public? true

      description "If true, this item is bulky/fresh and likely to have leftovers (e.g. Kale, Cabbage)."
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :account, GroceryPlanner.Accounts.Account do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :category, GroceryPlanner.Inventory.Category do
      attribute_writable? true
    end

    has_many :inventory_entries, GroceryPlanner.Inventory.InventoryEntry do
      destination_attribute :grocery_item_id
    end

    many_to_many :tags, GroceryPlanner.Inventory.GroceryItemTag do
      through GroceryPlanner.Inventory.GroceryItemTagging
      source_attribute_on_join_resource :grocery_item_id
      destination_attribute_on_join_resource :tag_id
    end
  end
end
