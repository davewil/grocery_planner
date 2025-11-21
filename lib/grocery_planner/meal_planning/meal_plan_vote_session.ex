defmodule GroceryPlanner.MealPlanning.MealPlanVoteSession do
  use Ash.Resource,
    domain: GroceryPlanner.MealPlanning,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "meal_plan_vote_sessions"
    repo GroceryPlanner.Repo
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

    create_timestamp :created_at
    update_timestamp :updated_at
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

  multitenancy do
    strategy :attribute
    attribute :account_id
  end

  actions do
    defaults [:read]

    create :start do
      accept []

      argument :account_id, :uuid, allow_nil?: false

      change manage_relationship(:account_id, :account, type: :append)
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

    policy action_type([:update]) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end
  end

  # Custom changes
  defmodule SetEndsAt do
    use Ash.Resource.Change

    def change(changeset, _opts, _ctx) do
      starts_at = Ash.Changeset.get_attribute(changeset, :starts_at) || DateTime.utc_now()
      ends_at = DateTime.add(starts_at, 48 * 3600, :second)
      Ash.Changeset.change_attribute(changeset, :ends_at, ends_at)
    end
  end

  defmodule EnsureNoOpenSession do
    use Ash.Resource.Change

    def change(changeset, _opts, context) do
      account_id = Ash.Changeset.get_argument(changeset, :account_id)

      # Read all sessions and filter in Elixir to avoid query issues
      sessions =
        GroceryPlanner.MealPlanning.MealPlanVoteSession
        |> Ash.read!(tenant: account_id, actor: context.actor)
        |> Enum.filter(fn session ->
          session.account_id == account_id && session.status == :open
        end)

      if Enum.any?(sessions) do
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