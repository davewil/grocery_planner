defmodule GroceryPlanner.MealPlanning.MealPlanVoteSession do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.MealPlanning,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource],
    primary_read_warning?: false

  postgres do
    table "meal_plan_vote_sessions"
    repo GroceryPlanner.Repo
  end

  json_api do
    type "vote_session"

    routes do
      base("/vote_sessions")

      index :read
      get(:read)
      post(:create_from_api)
      patch(:update)
      delete(:destroy)

      # Custom action to close voting
      patch(:close, route: "/:id/close")
    end
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

      filter expr(
               if is_nil(^arg(:since)) do
                 true
               else
                 updated_at >= ^arg(:since) or
                   (not is_nil(deleted_at) and deleted_at >= ^arg(:since))
               end
             )

      prepare build(sort: [updated_at: :asc])
    end

    create :start do
      accept []

      argument :account_id, :uuid, allow_nil?: false

      change manage_relationship(:account_id, :account, type: :append)
      change {GroceryPlanner.MealPlanning.MealPlanVoteSession.SetEndsAt, []}
      change {GroceryPlanner.MealPlanning.MealPlanVoteSession.EnsureNoOpenSession, []}
    end

    create :create_from_api do
      accept []

      argument :account_id, :uuid, allow_nil?: false, public?: true

      change set_attribute(:account_id, arg(:account_id))
      change {GroceryPlanner.MealPlanning.MealPlanVoteSession.SetEndsAt, []}
      change {GroceryPlanner.MealPlanning.MealPlanVoteSession.EnsureNoOpenSession, []}
    end

    update :update do
      accept [:ends_at, :status]
    end

    update :close do
      accept []

      change set_attribute(:status, :closed)
    end

    update :mark_processed do
      accept [:winning_recipe_ids]

      change set_attribute(:status, :processed)
      change set_attribute(:processed_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action(:start) do
      authorize_if actor_present()
    end

    policy action(:create_from_api) do
      authorize_if actor_present()
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

    attribute :starts_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
      public? true
    end

    attribute :ends_at, :utc_datetime do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:open, :closed, :processed]
      default :open
      public? true
    end

    attribute :processed_at, :utc_datetime do
      public? true
    end

    attribute :winning_recipe_ids, {:array, :uuid} do
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

    has_many :vote_entries, GroceryPlanner.MealPlanning.MealPlanVoteEntry do
      destination_attribute :vote_session_id
    end
  end

  # Custom changes
  defmodule SetEndsAt do
    @moduledoc false
    use Ash.Resource.Change

    def change(changeset, _opts, _ctx) do
      starts_at = Ash.Changeset.get_attribute(changeset, :starts_at) || DateTime.utc_now()
      ends_at = DateTime.add(starts_at, 48 * 3600, :second)
      Ash.Changeset.change_attribute(changeset, :ends_at, ends_at)
    end
  end

  defmodule EnsureNoOpenSession do
    @moduledoc false
    use Ash.Resource.Change

    def change(changeset, _opts, context) do
      account_id = Ash.Changeset.get_argument(changeset, :account_id)

      # Use domain code interface instead of direct Ash.read!
      {:ok, sessions} =
        GroceryPlanner.MealPlanning.list_vote_sessions(
          tenant: account_id,
          actor: context.actor
        )

      open_sessions =
        Enum.filter(sessions, fn session ->
          session.account_id == account_id && session.status == :open
        end)

      if Enum.any?(open_sessions) do
        Ash.Changeset.add_error(changeset,
          field: :status,
          message: "An open voting session already exists"
        )
      else
        changeset
      end
    end
  end
end
