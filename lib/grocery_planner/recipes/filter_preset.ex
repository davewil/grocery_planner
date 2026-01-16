defmodule GroceryPlanner.Recipes.FilterPreset do
  @moduledoc """
  Saved filter presets for recipe discovery in the meal planner.

  Users can save their frequently used filter combinations as presets
  (e.g., "Weeknight quick wins", "Mediterranean", "Keto-friendly").
  """
  use Ash.Resource,
    domain: GroceryPlanner.Recipes,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "filter_presets"
    repo GroceryPlanner.Repo
  end

  code_interface do
    define :create_filter_preset, action: :create
    define :list_filter_presets, action: :read
    define :get_filter_preset, action: :read, get_by: [:id]
    define :update_filter_preset, action: :update
    define :destroy_filter_preset, action: :destroy
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :criteria]

      argument :user_id, :uuid, allow_nil?: false

      change set_attribute(:user_id, arg(:user_id))
    end

    update :update do
      accept [:name, :criteria]
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action_type(:create) do
      authorize_if expr(^arg(:user_id) == ^actor(:id))
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      description "Display name for the preset (e.g., 'Weeknight Quick Wins')"
    end

    attribute :criteria, :map do
      allow_nil? false
      public? true
      default %{}

      description """
      Filter criteria stored as a map with keys:
      - search: string (text search)
      - filter: string ("quick", "pantry", or "")
      - difficulty: string ("easy", "medium", "hard", or "")
      - cuisine: string (free text cuisine filter)
      - dietary_needs: list of atoms ([:vegan, :gluten_free, etc.])
      """
    end

    attribute :user_id, :uuid do
      allow_nil? false
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
  end
end
