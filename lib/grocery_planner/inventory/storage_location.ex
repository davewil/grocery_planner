defmodule GroceryPlanner.Inventory.StorageLocation do
  use Ash.Resource,
    domain: GroceryPlanner.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    table "storage_locations"
    repo GroceryPlanner.Repo
  end

  json_api do
    type "storage_location"

    routes do
      base("/storage_locations")
      get(:read)
      index :read
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  code_interface do
    define :read
    define :by_id, action: :read, get_by: [:id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :temperature_zone]
      argument :account_id, :uuid, allow_nil?: false

      change manage_relationship(:account_id, :account, type: :append)
    end

    update :update do
      accept [:name, :temperature_zone]
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action_type([:create, :update, :destroy]) do
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

    attribute :temperature_zone, :atom do
      constraints one_of: [:frozen, :cold, :cool, :room_temp]
      public? true
    end

    attribute :account_id, :uuid do
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :account, GroceryPlanner.Accounts.Account do
      allow_nil? false
      attribute_writable? true
    end

    has_many :inventory_entries, GroceryPlanner.Inventory.InventoryEntry do
      destination_attribute :storage_location_id
    end
  end

  identities do
    identity :unique_name_per_account, [:account_id, :name]
  end
end
