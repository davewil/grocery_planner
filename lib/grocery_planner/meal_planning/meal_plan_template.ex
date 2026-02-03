defmodule GroceryPlanner.MealPlanning.MealPlanTemplate do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.MealPlanning,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    table "meal_plan_templates"
    repo GroceryPlanner.Repo
  end

  json_api do
    type "meal_plan_template"

    routes do
      base("/meal_plan_templates")

      index :read
      get(:read)
      post(:create)
      patch(:update)
      delete(:destroy)

      patch(:activate, route: "/:id/activate")
      patch(:deactivate, route: "/:id/deactivate")
    end
  end

  code_interface do
    domain GroceryPlanner.MealPlanning

    define :create_meal_plan_template, action: :create
    define :get_meal_plan_template, action: :read, get_by: [:id]
    define :list_meal_plan_templates, action: :read
    define :update_meal_plan_template, action: :update
    define :destroy_meal_plan_template, action: :destroy
    define :activate_meal_plan_template, action: :activate
    define :deactivate_meal_plan_template, action: :deactivate
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :is_active]

      argument :account_id, :uuid, allow_nil?: false

      change set_attribute(:account_id, arg(:account_id))
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

    policy action_type(:create) do
      # For create, we rely on multitenancy - the tenant is set by the ApiAuth plug
      # and is the account_id. If the user can authenticate and set the tenant,
      # they can create items in that tenant.
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
