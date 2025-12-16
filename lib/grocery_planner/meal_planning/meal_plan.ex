defmodule GroceryPlanner.MealPlanning.MealPlan do
  use Ash.Resource,
    domain: GroceryPlanner.MealPlanning,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    table "meal_plans"
    repo GroceryPlanner.Repo
  end

  json_api do
    type "meal_plan"

    routes do
      base("/meal_plans")
      get(:read)
      index :read
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :recipe_id,
        :scheduled_date,
        :meal_type,
        :servings,
        :notes,
        :status
      ]

      argument :account_id, :uuid, allow_nil?: false

      change manage_relationship(:account_id, :account, type: :append)
    end

    update :update do
      accept [
        :recipe_id,
        :scheduled_date,
        :meal_type,
        :servings,
        :notes,
        :status,
        :completed_at
      ]

      require_atomic? false
    end

    update :complete do
      accept []

      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)

      require_atomic? false
    end

    update :skip do
      accept []

      change set_attribute(:status, :skipped)

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

    attribute :scheduled_date, :date do
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

    attribute :notes, :string do
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:planned, :completed, :skipped]
      default :planned
      public? true
    end

    attribute :completed_at, :utc_datetime do
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

    belongs_to :recipe, GroceryPlanner.Recipes.Recipe do
      allow_nil? false
      attribute_writable? true
    end
  end

  calculations do
    calculate :requires_shopping, :boolean do
      calculation expr(not recipe.can_make)
    end
  end
end
