defmodule GroceryPlanner.Analytics.UsageLog do
  use Ash.Resource,
    domain: GroceryPlanner.Analytics,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "usage_logs"
    repo GroceryPlanner.Repo
  end

  code_interface do
    define :create
    define :read
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :quantity,
        :unit,
        :reason,
        :occurred_at,
        :cost,
        :grocery_item_id
      ]

      argument :account_id, :uuid, allow_nil?: false

      change manage_relationship(:account_id, :account, type: :append)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action_type([:create, :destroy]) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end
  end

  multitenancy do
    strategy :attribute
    attribute :account_id
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity, :decimal do
      allow_nil? false
      public? true
    end

    attribute :unit, :string do
      public? true
    end

    attribute :reason, :atom do
      constraints one_of: [:consumed, :expired, :wasted, :donated]
      allow_nil? false
      public? true
    end

    attribute :occurred_at, :utc_datetime_usec do
      allow_nil? false
      default &DateTime.utc_now/0
      public? true
    end

    attribute :cost, AshMoney.Types.Money do
      public? true
    end

    attribute :account_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :grocery_item_id, :uuid do
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
  end

  relationships do
    belongs_to :account, GroceryPlanner.Accounts.Account do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :grocery_item, GroceryPlanner.Inventory.GroceryItem do
      allow_nil? false
      attribute_writable? true
    end
  end
end
