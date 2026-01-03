defmodule GroceryPlanner.Accounts.User do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "users"
    repo GroceryPlanner.Repo
  end

  code_interface do
    define :create, args: [:email, :name, :password]
    define :read
    define :update
    define :confirm
    define :destroy
    define :by_id, action: :read, get_by: [:id]
    define :by_email, args: [:email], get?: true
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:email, :name]
      argument :password, :string, allow_nil?: false, sensitive?: true

      change fn changeset, _ ->
        case Ash.Changeset.get_argument(changeset, :password) do
          nil ->
            changeset

          password ->
            Ash.Changeset.change_attribute(
              changeset,
              :hashed_password,
              Bcrypt.hash_pwd_salt(password)
            )
        end
      end
    end

    update :update do
      accept [:name, :email, :theme]
    end

    update :confirm do
      accept []
      require_atomic? false

      change fn changeset, _ ->
        Ash.Changeset.change_attribute(changeset, :confirmed_at, DateTime.utc_now())
      end
    end

    read :by_email do
      argument :email, :ci_string, allow_nil?: false
      filter expr(email == ^arg(:email))
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
      public? false
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :theme, :string do
      allow_nil? false
      default "fresh"
      public? true
    end

    attribute :confirmed_at, :utc_datetime do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :memberships, GroceryPlanner.Accounts.AccountMembership do
      destination_attribute :user_id
    end

    many_to_many :accounts, GroceryPlanner.Accounts.Account do
      through GroceryPlanner.Accounts.AccountMembership
      source_attribute_on_join_resource :user_id
      destination_attribute_on_join_resource :account_id
    end
  end

  identities do
    identity :unique_email, [:email]
  end
end
