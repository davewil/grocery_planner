defmodule GroceryPlanner.Inventory.Receipt do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "receipts"
    repo GroceryPlanner.Repo
  end

  code_interface do
    define :create
    define :read
    define :by_id, action: :read, get_by: [:id]
    define :update
    define :destroy
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:image_path]
      argument :account_id, :uuid, allow_nil?: false
      change set_attribute(:account_id, arg(:account_id))
    end

    update :update do
      accept [:status, :job_id, :merchant, :total_amount, :scanned_date, :items]
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action_type(:create) do
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

    attribute :image_path, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:pending, :processing, :review, :completed, :failed]
      default :pending
      allow_nil? false
      public? true
    end

    attribute :job_id, :string do
      public? true
    end

    attribute :merchant, :string do
      public? true
    end

    attribute :total_amount, AshMoney.Types.Money do
      public? true
    end

    attribute :scanned_date, :date do
      public? true
    end

    attribute :items, {:array, GroceryPlanner.Inventory.ReceiptItem} do
      public? true
      default []
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
  end
end
