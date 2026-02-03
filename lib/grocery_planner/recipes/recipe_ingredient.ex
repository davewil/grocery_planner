defmodule GroceryPlanner.Recipes.RecipeIngredient do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.Recipes,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    table "recipe_ingredients"
    repo GroceryPlanner.Repo
  end

  json_api do
    type "recipe_ingredient"

    routes do
      base("/recipes/:recipe_id/ingredients")

      index :read do
        derive_filter?(true)
      end

      get(:read)
      post(:create_from_api)
      patch(:update)
      delete(:destroy)
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :recipe_id,
        :grocery_item_id,
        :quantity,
        :unit,
        :is_optional,
        :substitution_notes,
        :preparation,
        :sort_order,
        :usage_type
      ]

      argument :account_id, :uuid, allow_nil?: false

      change manage_relationship(:account_id, :account, type: :append)
    end

    create :create_from_api do
      accept [
        :grocery_item_id,
        :quantity,
        :unit,
        :is_optional,
        :substitution_notes,
        :preparation,
        :sort_order,
        :usage_type
      ]

      argument :recipe_id, :uuid, allow_nil?: false

      change fn changeset, context ->
        recipe_id = Ash.Changeset.get_argument(changeset, :recipe_id)
        tenant = context.tenant

        opts = [authorize?: false]
        opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

        case GroceryPlanner.Recipes.get_recipe(recipe_id, opts) do
          {:ok, recipe} ->
            changeset
            |> Ash.Changeset.manage_relationship(:recipe, recipe, type: :append)
            |> Ash.Changeset.change_attribute(:account_id, recipe.account_id)

          {:error, _} ->
            Ash.Changeset.add_error(changeset, field: :recipe_id, message: "not found")
        end
      end
    end

    update :update do
      accept [
        :quantity,
        :unit,
        :is_optional,
        :substitution_notes,
        :preparation,
        :sort_order,
        :usage_type
      ]

      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action_type(:create) do
      authorize_if GroceryPlanner.Checks.ActorMemberOfAccount
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

    attribute :quantity, :decimal do
      allow_nil? true
      public? true
    end

    attribute :unit, :string do
      public? true
    end

    attribute :is_optional, :boolean do
      default false
      public? true
    end

    attribute :substitution_notes, :string do
      public? true
    end

    attribute :preparation, :string do
      public? true
    end

    attribute :usage_type, :atom do
      constraints one_of: [:fresh, :leftover]
      default :fresh
      public? true

      description "Indicates if the ingredient is bought fresh or used as a leftover from a previous meal."
    end

    attribute :sort_order, :integer do
      default 0
      public? true
    end

    attribute :account_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :recipe_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :grocery_item_id, :uuid do
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

    belongs_to :recipe, GroceryPlanner.Recipes.Recipe do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :grocery_item, GroceryPlanner.Inventory.GroceryItem do
      allow_nil? false
      attribute_writable? true
    end
  end
end
