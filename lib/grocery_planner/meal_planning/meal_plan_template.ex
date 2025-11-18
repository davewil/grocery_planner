defmodule GroceryPlanner.MealPlanning.MealPlanTemplate do
  use Ash.Resource,
    domain: GroceryPlanner.MealPlanning,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "meal_plan_templates"
    repo GroceryPlanner.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :is_active]

      argument :account_id, :uuid, allow_nil?: false

      change manage_relationship(:account_id, :account, type: :append)
    end

    update :update do
      accept [:name, :is_active]

      require_atomic? false
    end

    update :activate do
      accept []

      change set_attribute(:is_active, true)

      require_atomic? false
    end

    update :deactivate do
      accept []

      change set_attribute(:is_active, false)

      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action_type([:create, :update, :destroy]) do
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

    attribute :is_active, :boolean do
      default false
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

    has_many :template_entries, GroceryPlanner.MealPlanning.MealPlanTemplateEntry do
      destination_attribute :template_id
    end
  end
end
