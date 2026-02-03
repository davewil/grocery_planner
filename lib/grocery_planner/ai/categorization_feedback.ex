defmodule GroceryPlanner.AI.CategorizationFeedback do
  @moduledoc """
  Stores user feedback on AI categorization predictions.
  Used to track correction rates and improve the model over time.
  """
  use Ash.Resource,
    domain: GroceryPlanner.AI,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "ai_categorization_feedback"
    repo GroceryPlanner.Repo
  end

  code_interface do
    define :create
    define :read
    define :list_for_export, args: [:since]
    define :corrections_only

    define :log_correction,
      action: :create,
      args: [:item_name, :predicted_category, :predicted_confidence, :user_selected_category]
  end

  actions do
    defaults [:read, :destroy]

    read :list_for_export do
      argument :since, :utc_datetime, allow_nil?: true

      prepare fn query, _context ->
        require Ash.Query

        case Ash.Changeset.get_argument(query, :since) do
          nil -> query
          since -> Ash.Query.filter(query, created_at >= ^since)
        end
      end
    end

    read :corrections_only do
      filter expr(was_correction == true)
    end

    create :create do
      accept [
        :item_name,
        :predicted_category,
        :predicted_confidence,
        :user_selected_category,
        :was_correction,
        :model_version
      ]

      argument :account_id, :uuid, allow_nil?: false
      change manage_relationship(:account_id, :account, type: :append)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action_type(:create) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end
  end

  multitenancy do
    strategy :attribute
    attribute :account_id
  end

  attributes do
    uuid_primary_key :id

    attribute :item_name, :string do
      allow_nil? false
      public? true
    end

    attribute :predicted_category, :string do
      allow_nil? false
      public? true
    end

    attribute :predicted_confidence, :float do
      allow_nil? false
      public? true
    end

    attribute :user_selected_category, :string do
      allow_nil? false
      public? true
    end

    attribute :was_correction, :boolean do
      default false
      public? true
    end

    attribute :model_version, :string do
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
  end
end
