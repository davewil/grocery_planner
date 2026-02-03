defmodule GroceryPlanner.Inventory.GroceryItem do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource],
    primary_read_warning?: false

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
    define :create_grocery_item, action: :create
    define :read
    define :get_grocery_item, action: :read, get_by: [:id]
    define :get_item_by_name, action: :by_name, args: [:name], get?: true
    define :list_items_with_tags, action: :list_with_tags, args: [:filter_tag_ids]
    define :sync_grocery_items, action: :sync, args: [:since]
  end

  actions do
    defaults []

    read :read do
      primary? true
      filter expr(is_nil(deleted_at))
    end

    destroy :destroy do
      primary? true
      soft? true
      change set_attribute(:deleted_at, &DateTime.utc_now/0)
    end

    read :sync do
      argument :since, :utc_datetime_usec

      filter expr(
               if is_nil(^arg(:since)) do
                 true
               else
                 updated_at >= ^arg(:since) or
                   (not is_nil(deleted_at) and deleted_at >= ^arg(:since))
               end
             )

      prepare build(sort: [updated_at: :asc])
    end

    read :list_with_tags do
      argument :filter_tag_ids, {:array, :uuid}

      prepare build(load: [:tags])

      filter expr(is_nil(deleted_at))

      filter expr(
               is_nil(^arg(:filter_tag_ids)) or
                 count(tags, query: [filter: expr(id in ^arg(:filter_tag_ids))]) ==
                   length(^arg(:filter_tag_ids))
             )
    end

    read :by_name do
      argument :name, :string, allow_nil?: false
      filter expr(is_nil(deleted_at))
      filter expr(fragment("lower(?) = lower(?)", name, ^arg(:name)))
    end

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

    attribute :deleted_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :created_at, public?: true
    update_timestamp :updated_at, public?: true
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
