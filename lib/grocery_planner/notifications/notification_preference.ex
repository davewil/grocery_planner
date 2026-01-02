defmodule GroceryPlanner.Notifications.NotificationPreference do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.Notifications,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    table "notification_preferences"
    repo GroceryPlanner.Repo
  end

  json_api do
    type "notification_preference"

    routes do
      base("/notification_preferences")
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
        :expiration_alerts_enabled,
        :expiration_alert_days,
        :recipe_suggestions_enabled,
        :email_notifications_enabled,
        :in_app_notifications_enabled
      ]

      argument :user_id, :uuid, allow_nil?: false
      argument :account_id, :uuid, allow_nil?: false

      change manage_relationship(:user_id, :user, type: :append)
      change manage_relationship(:account_id, :account, type: :append)
    end

    update :update do
      accept [
        :expiration_alerts_enabled,
        :expiration_alert_days,
        :recipe_suggestions_enabled,
        :email_notifications_enabled,
        :in_app_notifications_enabled
      ]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:user)
    end

    policy action_type(:create) do
      authorize_if relating_to_actor(:user)
    end

    policy action_type([:update, :destroy]) do
      authorize_if relates_to_actor_via(:user)
    end
  end

  multitenancy do
    strategy :attribute
    attribute :account_id
  end

  attributes do
    uuid_primary_key :id

    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :account_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :expiration_alerts_enabled, :boolean do
      default true
      public? true
    end

    attribute :expiration_alert_days, :integer do
      default 7
      public? true
      description "Days before expiration to send alerts"
    end

    attribute :recipe_suggestions_enabled, :boolean do
      default true
      public? true
    end

    attribute :email_notifications_enabled, :boolean do
      default false
      public? true
    end

    attribute :in_app_notifications_enabled, :boolean do
      default true
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, GroceryPlanner.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :account, GroceryPlanner.Accounts.Account do
      allow_nil? false
      attribute_writable? true
    end
  end
end
