defmodule GroceryPlanner.Shopping.ShoppingList do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.Shopping,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource],
    primary_read_warning?: false

  postgres do
    table "shopping_lists"
    repo GroceryPlanner.Repo
  end

  json_api do
    type "shopping_list"

    routes do
      base("/shopping_lists")
      get(:read)
      index :read
      post(:create)
      patch(:update)
      delete(:destroy)

      post(:generate_from_meal_plans, route: "/generate_from_meal_plans")
    end
  end

  code_interface do
    domain GroceryPlanner.Shopping

    define :create
    define :read
    define :update
    define :destroy
    define :complete
    define :archive
    define :reactivate
    define :generate_from_meal_plans
    define :list_active_or_completed_shopping_lists, action: :active_or_completed
    define :sync_shopping_lists, action: :sync, args: [:since]
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

    read :active_or_completed do
      filter expr(is_nil(deleted_at))
      filter expr(status in [:active, :completed])
      prepare build(sort: [updated_at: :desc])
    end

    create :create do
      accept [
        :name,
        :status,
        :generated_from,
        :notes
      ]

      argument :account_id, :uuid, allow_nil?: false

      change manage_relationship(:account_id, :account, type: :append)
    end

    update :update do
      accept [
        :name,
        :status,
        :notes
      ]

      require_atomic? false
    end

    update :complete do
      accept []

      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)

      require_atomic? false
    end

    update :archive do
      accept []

      change set_attribute(:status, :archived)

      require_atomic? false
    end

    update :reactivate do
      accept []

      change set_attribute(:status, :active)
      change set_attribute(:completed_at, nil)

      require_atomic? false
    end

    create :generate_from_meal_plans do
      accept [:name, :notes]

      argument :account_id, :uuid, allow_nil?: false
      argument :start_date, :date, allow_nil?: false
      argument :end_date, :date, allow_nil?: false

      change manage_relationship(:account_id, :account, type: :append)
      change GroceryPlanner.Shopping.Changes.GenerateFromMealPlans
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

    attribute :name, :string do
      allow_nil? false
      default "Shopping List"
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:active, :completed, :archived]
      default :active
      public? true
    end

    attribute :generated_from, :atom do
      constraints one_of: [:manual, :meal_plan]
      default :manual
      public? true
    end

    attribute :generated_at, :utc_datetime do
      public? true
    end

    attribute :completed_at, :utc_datetime do
      public? true
    end

    attribute :notes, :string do
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

    has_many :items, GroceryPlanner.Shopping.ShoppingListItem do
      destination_attribute :shopping_list_id
    end
  end

  calculations do
    calculate :total_items, :integer do
      calculation expr(count(items, query: [filter: expr(not is_nil(id))]))
    end

    calculate :checked_items, :integer do
      calculation expr(count(items, query: [filter: expr(checked == true)]))
    end

    calculate :progress_percentage, :integer do
      calculation expr(
                    fragment(
                      "CASE WHEN ? > 0 THEN ROUND((? * 100.0) / ?) ELSE 0 END",
                      count(items, query: [filter: expr(not is_nil(id))]),
                      count(items, query: [filter: expr(checked == true)]),
                      count(items, query: [filter: expr(not is_nil(id))])
                    )
                  )
    end
  end
end
