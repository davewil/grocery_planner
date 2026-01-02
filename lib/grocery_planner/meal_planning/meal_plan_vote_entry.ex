defmodule GroceryPlanner.MealPlanning.MealPlanVoteEntry do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.MealPlanning,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "meal_plan_vote_entries"
    repo GroceryPlanner.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :vote do
      accept []

      argument :account_id, :uuid, allow_nil?: false
      argument :vote_session_id, :uuid, allow_nil?: false
      argument :recipe_id, :uuid, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false

      change manage_relationship(:account_id, :account, type: :append)
      change manage_relationship(:vote_session_id, :vote_session, type: :append)
      change manage_relationship(:recipe_id, :recipe, type: :append)
      change manage_relationship(:user_id, :user, type: :append)
      change {GroceryPlanner.MealPlanning.MealPlanVoteEntry.EnsureSessionOpen, []}
      change {GroceryPlanner.MealPlanning.MealPlanVoteEntry.EnsureUniqueVote, []}
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action(:vote) do
      authorize_if actor_present()
    end

    policy action_type([:destroy]) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end
  end

  multitenancy do
    strategy :attribute
    attribute :account_id
  end

  attributes do
    uuid_primary_key :id

    attribute :account_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :vote_session_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :recipe_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
  end

  relationships do
    belongs_to :account, GroceryPlanner.Accounts.Account do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :vote_session, GroceryPlanner.MealPlanning.MealPlanVoteSession do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :recipe, GroceryPlanner.Recipes.Recipe do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :user, GroceryPlanner.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
  end

  defmodule EnsureSessionOpen do
    @moduledoc false
    use Ash.Resource.Change

    def change(changeset, _opts, context) do
      vote_session_id = Ash.Changeset.get_argument(changeset, :vote_session_id)
      account_id = Ash.Changeset.get_argument(changeset, :account_id)

      # Use domain code interface instead of direct Ash.get
      session =
        GroceryPlanner.MealPlanning.get_vote_session(
          vote_session_id,
          tenant: account_id,
          actor: context.actor,
          authorize?: false
        )

      case session do
        {:ok, session} ->
          if session.status != :open or
               DateTime.compare(DateTime.utc_now(), session.ends_at) == :gt do
            Ash.Changeset.add_error(changeset,
              field: :vote_session_id,
              message: "Voting session is closed"
            )
          else
            changeset
          end

        {:error, _} ->
          Ash.Changeset.add_error(changeset,
            field: :vote_session_id,
            message: "Voting session not found"
          )
      end
    end
  end

  defmodule EnsureUniqueVote do
    @moduledoc false
    use Ash.Resource.Change

    def change(changeset, _opts, context) do
      account_id = Ash.Changeset.get_argument(changeset, :account_id)
      vote_session_id = Ash.Changeset.get_argument(changeset, :vote_session_id)
      recipe_id = Ash.Changeset.get_argument(changeset, :recipe_id)
      user_id = Ash.Changeset.get_argument(changeset, :user_id)

      existing =
        GroceryPlanner.MealPlanning.MealPlanVoteEntry
        |> Ash.Query.filter(
          account_id == ^account_id and vote_session_id == ^vote_session_id and
            recipe_id == ^recipe_id and
            user_id == ^user_id
        )
        |> Ash.exists?(tenant: account_id, actor: context.actor)

      if existing do
        Ash.Changeset.add_error(changeset,
          field: :recipe_id,
          message: "User already voted for this recipe"
        )
      else
        changeset
      end
    end
  end
end
