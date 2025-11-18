defmodule GroceryPlanner.Accounts.AccountMembership do
  use Ash.Resource,
    domain: GroceryPlanner.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "account_memberships"
    repo GroceryPlanner.Repo
  end

  code_interface do
    define :create, args: [:account_id, :user_id]
    define :read
    define :update
    define :destroy
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:role]
      argument :account_id, :uuid, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false

      change manage_relationship(:account_id, :account, type: :append)
      change manage_relationship(:user_id, :user, type: :append)
    end

    update :update do
      accept [:role]
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :atom do
      allow_nil? false
      default :member
      constraints one_of: [:owner, :admin, :member]
      public? true
    end

    create_timestamp :joined_at
  end

  relationships do
    belongs_to :account, GroceryPlanner.Accounts.Account do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :user, GroceryPlanner.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_user_account, [:user_id, :account_id]
  end
end
