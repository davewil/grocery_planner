defmodule GroceryPlanner.Recipes.RecipeTag do
  use Ash.Resource,
    domain: GroceryPlanner.Recipes,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "recipe_tags"
    repo GroceryPlanner.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :color]

      argument :account_id, :uuid, allow_nil?: false

      change manage_relationship(:account_id, :account, type: :append)
    end

    update :update do
      accept [:name, :color]
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action_type([:create, :update, :destroy]) do
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

    attribute :color, :string do
      public? true
      default "#3B82F6"
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

    many_to_many :recipes, GroceryPlanner.Recipes.Recipe do
      through GroceryPlanner.Recipes.RecipeTagging
      source_attribute_on_join_resource :tag_id
      destination_attribute_on_join_resource :recipe_id
    end
  end

  identities do
    identity :unique_name_per_account, [:account_id, :name]
  end
end
