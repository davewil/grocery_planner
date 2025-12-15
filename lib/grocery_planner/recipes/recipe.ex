defmodule GroceryPlanner.Recipes.Recipe do
  use Ash.Resource,
    domain: GroceryPlanner.Recipes,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  json_api do
    type("recipe")

    routes do
      base("/recipes")
      get(:read)
      index(:read)
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  postgres do
    table("recipes")
    repo(GroceryPlanner.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :name,
        :description,
        :instructions,
        :prep_time_minutes,
        :cook_time_minutes,
        :servings,
        :difficulty,
        :image_url,
        :source,
        :is_favorite
      ])

      argument(:account_id, :uuid, allow_nil?: false)

      change(manage_relationship(:account_id, :account, type: :append))
    end

    update :update do
      accept([
        :name,
        :description,
        :instructions,
        :prep_time_minutes,
        :cook_time_minutes,
        :servings,
        :difficulty,
        :image_url,
        :source,
        :is_favorite
      ])

      require_atomic?(false)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if(relates_to_actor_via([:account, :memberships, :user]))
    end

    policy action_type(:create) do
      authorize_if(GroceryPlanner.Checks.ActorMemberOfAccount)
    end

    policy action_type([:update, :destroy]) do
      authorize_if(relates_to_actor_via([:account, :memberships, :user]))
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:account_id)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :description, :string do
      public?(true)
    end

    attribute :instructions, :string do
      public?(true)
    end

    attribute :prep_time_minutes, :integer do
      public?(true)
    end

    attribute :cook_time_minutes, :integer do
      public?(true)
    end

    attribute :servings, :integer do
      default(4)
      public?(true)
    end

    attribute :difficulty, :atom do
      constraints(one_of: [:easy, :medium, :hard])
      default(:medium)
      public?(true)
    end

    attribute :image_url, :string do
      public?(true)
    end

    attribute :source, :string do
      public?(true)
    end

    attribute :is_favorite, :boolean do
      default(false)
      public?(true)
    end

    attribute :account_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :account, GroceryPlanner.Accounts.Account do
      allow_nil?(false)
      attribute_writable?(true)
    end

    has_many :recipe_ingredients, GroceryPlanner.Recipes.RecipeIngredient do
      destination_attribute(:recipe_id)
    end

    many_to_many :tags, GroceryPlanner.Recipes.RecipeTag do
      through(GroceryPlanner.Recipes.RecipeTagging)
      source_attribute_on_join_resource(:recipe_id)
      destination_attribute_on_join_resource(:tag_id)
    end

    has_many :meal_plans, GroceryPlanner.MealPlanning.MealPlan do
      destination_attribute(:recipe_id)
    end
  end

  calculations do
    calculate :total_time_minutes, :integer do
      calculation(expr(prep_time_minutes + cook_time_minutes))
    end

    calculate :ingredient_availability,
              :decimal,
              GroceryPlanner.Recipes.Calculations.IngredientAvailability do
      description("Percentage of recipe ingredients currently in stock (0.0 to 100.0)")
    end

    calculate :can_make, :boolean, GroceryPlanner.Recipes.Calculations.CanMake do
      description("Whether all required ingredients are currently available in inventory")
    end

    calculate :missing_ingredients,
              {:array, :string},
              GroceryPlanner.Recipes.Calculations.MissingIngredients do
      description("List of ingredient names not currently available in inventory")
    end
  end
end
