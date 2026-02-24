defmodule GroceryPlanner.Family.RecipePreference do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.Family,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    primary_read_warning?: false

  postgres do
    table "recipe_preferences"
    repo GroceryPlanner.Repo
  end

  code_interface do
    domain GroceryPlanner.Family
  end

  actions do
    defaults []

    read :read do
      primary? true
    end

    read :for_recipe do
      argument :recipe_id, :uuid, allow_nil?: false
      filter expr(recipe_id == ^arg(:recipe_id))
    end

    read :for_family_member do
      argument :family_member_id, :uuid, allow_nil?: false
      filter expr(family_member_id == ^arg(:family_member_id))
    end

    read :for_recipes do
      argument :recipe_ids, {:array, :uuid}, allow_nil?: false
      filter expr(recipe_id in ^arg(:recipe_ids))
    end

    create :set_preference do
      accept [:preference]
      argument :account_id, :uuid, allow_nil?: false
      argument :family_member_id, :uuid, allow_nil?: false
      argument :recipe_id, :uuid, allow_nil?: false

      change manage_relationship(:account_id, :account, type: :append)
      change set_attribute(:family_member_id, arg(:family_member_id))
      change set_attribute(:recipe_id, arg(:recipe_id))

      upsert? true
      upsert_identity :unique_member_recipe
      upsert_fields [:preference]
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action_type(:create) do
      authorize_if GroceryPlanner.Checks.ActorMemberOfAccount
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end
  end

  multitenancy do
    strategy :attribute
    attribute :account_id
  end

  attributes do
    uuid_primary_key :id

    attribute :preference, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:liked, :disliked]
    end

    attribute :account_id, :uuid do
      allow_nil? false
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

    belongs_to :family_member, GroceryPlanner.Family.FamilyMember do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :recipe, GroceryPlanner.Recipes.Recipe do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_member_recipe, [:family_member_id, :recipe_id]
  end
end
