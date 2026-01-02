defmodule GroceryPlanner.Recipes.RecipeIngredient do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.Recipes,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "recipe_ingredients"
    repo GroceryPlanner.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :recipe_id,
        :grocery_item_id,
        :quantity,
        :unit,
        :is_optional,
        :substitution_notes,
        :preparation,
        :sort_order
      ]

      argument :account_id, :uuid, allow_nil?: false

      change manage_relationship(:account_id, :account, type: :append)
    end

    update :update do
      accept [
        :quantity,
        :unit,
        :is_optional,
        :substitution_notes,
        :preparation,
        :sort_order
      ]

      require_atomic? false
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

    attribute :quantity, :decimal do
      allow_nil? false
      public? true
    end

    attribute :unit, :string do
      public? true
    end

    attribute :is_optional, :boolean do
      default false
      public? true
    end

    attribute :substitution_notes, :string do
      public? true
    end

    attribute :preparation, :string do
      public? true
    end

    attribute :sort_order, :integer do
      default 0
      public? true
    end

    attribute :account_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :recipe_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :grocery_item_id, :uuid do
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

    belongs_to :recipe, GroceryPlanner.Recipes.Recipe do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :grocery_item, GroceryPlanner.Inventory.GroceryItem do
      allow_nil? false
      attribute_writable? true
    end
  end
end
