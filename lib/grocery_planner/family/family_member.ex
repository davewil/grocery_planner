defmodule GroceryPlanner.Family.FamilyMember do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.Family,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    primary_read_warning?: false

  postgres do
    table "family_members"
    repo GroceryPlanner.Repo
  end

  code_interface do
    domain GroceryPlanner.Family
  end

  actions do
    defaults []

    read :read do
      primary? true
      filter expr(is_nil(deleted_at))
    end

    create :create do
      accept [:name]
      argument :account_id, :uuid, allow_nil?: false
      change manage_relationship(:account_id, :account, type: :append)
    end

    update :update do
      accept [:name]
      require_atomic? false
    end

    destroy :destroy do
      primary? true
      soft? true
      change set_attribute(:deleted_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action_type(:create) do
      authorize_if GroceryPlanner.Checks.ActorMemberOfAccount
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

    attribute :account_id, :uuid do
      allow_nil? false
      public? true
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

    has_many :recipe_preferences, GroceryPlanner.Family.RecipePreference do
      destination_attribute :family_member_id
    end
  end
end
