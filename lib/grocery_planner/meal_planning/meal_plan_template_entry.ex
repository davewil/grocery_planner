defmodule GroceryPlanner.MealPlanning.MealPlanTemplateEntry do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.MealPlanning,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "meal_plan_template_entries"
    repo GroceryPlanner.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :template_id,
        :recipe_id,
        :day_of_week,
        :meal_type,
        :servings
      ]

      argument :account_id, :uuid, allow_nil?: false

      change manage_relationship(:account_id, :account, type: :append)
    end

    update :update do
      accept [
        :recipe_id,
        :day_of_week,
        :meal_type,
        :servings
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

    attribute :day_of_week, :integer do
      constraints min: 0, max: 6
      allow_nil? false
      public? true
    end

    attribute :meal_type, :atom do
      constraints one_of: [:breakfast, :lunch, :dinner, :snack]
      allow_nil? false
      public? true
    end

    attribute :servings, :integer do
      default 4
      public? true
    end

    attribute :template_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :recipe_id, :uuid do
      allow_nil? false
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

    belongs_to :template, GroceryPlanner.MealPlanning.MealPlanTemplate do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :recipe, GroceryPlanner.Recipes.Recipe do
      allow_nil? false
      attribute_writable? true
    end
  end
end
