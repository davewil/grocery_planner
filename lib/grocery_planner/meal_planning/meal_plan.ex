defmodule GroceryPlanner.MealPlanning.MealPlan do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.MealPlanning,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource],
    primary_read_warning?: false

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

      patch(:complete, route: "/:id/complete")
    end
  end

  code_interface do
    domain GroceryPlanner.MealPlanning

    define :create_meal_plan, action: :create
    define :update_meal_plan, action: :update
    define :list_meal_plans_by_date_range, action: :by_date_range, args: [:start_date, :end_date]
    define :list_recent_meal_plans, action: :recent, args: [:since]
    define :read
    define :destroy
  end

  actions do
    defaults []

    read :read do
      primary? true
      filter expr(is_nil(deleted_at))
    end

    destroy :destroy do
      primary? true
      soft? true
      change set_attribute(:deleted_at, &DateTime.utc_now/0)
    end

    read :sync do
      argument :since, :utc_datetime_usec
      argument :limit, :integer

      filter expr(
               if is_nil(^arg(:since)) do
                 true
               else
                 updated_at >= ^arg(:since) or
                   (not is_nil(deleted_at) and deleted_at >= ^arg(:since))
               end
             )

      prepare build(sort: [updated_at: :asc])

      prepare fn query, _context ->
        case Ash.Query.get_argument(query, :limit) do
          nil -> query
          limit -> Ash.Query.limit(query, limit)
        end
      end
    end

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

    read :by_date_range do
      argument :start_date, :date, allow_nil?: false
      argument :end_date, :date, allow_nil?: false

      filter expr(is_nil(deleted_at))
      filter expr(scheduled_date >= ^arg(:start_date) and scheduled_date < ^arg(:end_date))
    end

    read :recent do
      argument :since, :date, allow_nil?: false

      filter expr(is_nil(deleted_at))
      filter expr(scheduled_date >= ^arg(:since))
      prepare build(sort: [scheduled_date: :desc])
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
