defmodule GroceryPlanner.MealPlanning.MealPlanVoteEntry do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.MealPlanning,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    table "meal_plan_vote_entries"
    repo GroceryPlanner.Repo
  end

  json_api do
    type "vote_entry"

    routes do
      base("/vote_sessions/:vote_session_id/entries")

      index :list_by_session
      get(:read)
      post(:create_from_api)
      delete(:destroy)
    end
  end

  code_interface do
    define :list_entries_for_session, action: :by_session, args: [:vote_session_id]
  end

  actions do
    defaults [:read, :destroy]

    read :by_session do
      argument :vote_session_id, :uuid, allow_nil?: false
      filter expr(vote_session_id == ^arg(:vote_session_id))
    end

    read :list_by_session do
      argument :vote_session_id, :uuid, allow_nil?: false, public?: true
      filter expr(vote_session_id == ^arg(:vote_session_id))
    end

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

    create :create_from_api do
      accept [:recipe_id]

      argument :vote_session_id, :uuid, allow_nil?: false, public?: true

      change {GroceryPlanner.MealPlanning.MealPlanVoteEntry.DeriveFromSession, []}
      change {GroceryPlanner.MealPlanning.MealPlanVoteEntry.SetUserFromActor, []}
      change {GroceryPlanner.MealPlanning.MealPlanVoteEntry.EnsureSessionOpenForApi, []}
      change {GroceryPlanner.MealPlanning.MealPlanVoteEntry.EnsureUniqueVoteForApi, []}
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action(:vote) do
      authorize_if actor_present()
    end

    policy action(:create_from_api) do
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

  # API-specific change modules

  defmodule DeriveFromSession do
    @moduledoc false
    use Ash.Resource.Change

    def change(changeset, _opts, _context) do
      vote_session_id = Ash.Changeset.get_argument(changeset, :vote_session_id)

      # Look up session directly from repo to bypass multitenancy
      # since we're deriving the tenant from the session itself
      case GroceryPlanner.Repo.get(
             GroceryPlanner.MealPlanning.MealPlanVoteSession,
             vote_session_id
           ) do
        nil ->
          Ash.Changeset.add_error(changeset,
            field: :vote_session_id,
            message: "Vote session not found"
          )

        session ->
          changeset
          |> Ash.Changeset.change_attribute(:account_id, session.account_id)
          |> Ash.Changeset.change_attribute(:vote_session_id, session.id)
      end
    end
  end

  defmodule SetUserFromActor do
    @moduledoc false
    use Ash.Resource.Change

    def change(changeset, _opts, context) do
      case context.actor do
        %{id: user_id} ->
          Ash.Changeset.change_attribute(changeset, :user_id, user_id)

        _ ->
          Ash.Changeset.add_error(changeset,
            field: :user_id,
            message: "User must be authenticated"
          )
      end
    end
  end

  defmodule EnsureSessionOpenForApi do
    @moduledoc false
    use Ash.Resource.Change

    def change(changeset, _opts, context) do
      vote_session_id = Ash.Changeset.get_argument(changeset, :vote_session_id)
      account_id = Ash.Changeset.get_attribute(changeset, :account_id)

      case GroceryPlanner.MealPlanning.get_vote_session(vote_session_id,
             tenant: account_id,
             actor: context.actor,
             authorize?: false
           ) do
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

  defmodule EnsureUniqueVoteForApi do
    @moduledoc false
    use Ash.Resource.Change

    def change(changeset, _opts, context) do
      account_id = Ash.Changeset.get_attribute(changeset, :account_id)
      vote_session_id = Ash.Changeset.get_argument(changeset, :vote_session_id)
      recipe_id = Ash.Changeset.get_attribute(changeset, :recipe_id)
      user_id = Ash.Changeset.get_attribute(changeset, :user_id)

      # Skip check if required values are missing (validation will catch this later)
      if is_nil(account_id) or is_nil(vote_session_id) or is_nil(recipe_id) or is_nil(user_id) do
        changeset
      else
        existing =
          GroceryPlanner.MealPlanning.MealPlanVoteEntry
          |> Ash.Query.filter(
            vote_session_id == ^vote_session_id and
              recipe_id == ^recipe_id and
              user_id == ^user_id
          )
          |> Ash.exists?(tenant: account_id, actor: context.actor, authorize?: false)

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
end
