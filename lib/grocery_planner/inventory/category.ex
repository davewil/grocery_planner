defmodule GroceryPlanner.Inventory.Category do
  use Ash.Resource,
    domain: GroceryPlanner.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  json_api do
    type("category")

    routes do
      base("/categories")
      get(:read)
      index(:read)
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  postgres do
    table("categories")
    repo(GroceryPlanner.Repo)
  end

  code_interface do
    define(:create)
    define(:read)
    define(:by_id, action: :read, get_by: [:id])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :icon, :sort_order])
      argument(:account_id, :uuid, allow_nil?: false)

      change(manage_relationship(:account_id, :account, type: :append))
    end

    update :update do
      accept([:name, :icon, :sort_order])
      require_atomic?(false)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if(relates_to_actor_via([:account, :memberships, :user]))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if(relates_to_actor_via([:account, :memberships, :user]))
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:account_id)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :icon, :string do
      public?(true)
    end

    attribute :sort_order, :integer do
      default(0)
      public?(true)
    end

    attribute :account_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :account, GroceryPlanner.Accounts.Account do
      allow_nil?(false)
      attribute_writable?(true)
    end

    has_many :grocery_items, GroceryPlanner.Inventory.GroceryItem do
      destination_attribute(:category_id)
    end
  end

  aggregates do
    count(:item_count, :grocery_items)
  end

  identities do
    identity(:unique_name_per_account, [:account_id, :name])
  end
end
