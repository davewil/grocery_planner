defmodule GroceryPlanner.Recipes.Recipe do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.Recipes,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    table "recipes"
    repo GroceryPlanner.Repo
  end

  json_api do
    type "recipe"

    routes do
      base("/recipes")
      get(:read)
      index :read
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  code_interface do
    domain GroceryPlanner.Recipes

    define :list_favorite_recipes, action: :favorites
    define :list_recipes_for_meal_planner, action: :meal_planner_recipes
    define :list_recipes_sorted, action: :list_all_sorted
    define :read
    define :create
    define :update
    define :destroy
  end

  actions do
    defaults [:read, :destroy]

    read :meal_planner_recipes do
      prepare build(
                load: [
                  :total_time_minutes,
                  :recipe_ingredients,
                  :can_make,
                  :ingredient_availability,
                  follow_up_recipes: [:recipe_ingredients],
                  parent_recipe: [follow_up_recipes: [:recipe_ingredients]]
                ]
              )

      prepare build(sort: [name: :asc])
    end

    create :create do
      accept [
        :name,
        :description,
        :instructions,
        :prep_time_minutes,
        :cook_time_minutes,
        :servings,
        :difficulty,
        :image_url,
        :source,
        :is_favorite,
        :is_base_recipe,
        :is_follow_up,
        :parent_recipe_id,
        :freezable,
        :preservation_tip,
        :waste_reduction_tip,
        :cuisine,
        :dietary_needs
      ]

      argument :account_id, :uuid, allow_nil?: false

      change manage_relationship(:account_id, :account, type: :append)
    end

    update :update do
      accept [
        :name,
        :description,
        :instructions,
        :prep_time_minutes,
        :cook_time_minutes,
        :servings,
        :difficulty,
        :image_url,
        :source,
        :is_favorite,
        :is_base_recipe,
        :is_follow_up,
        :parent_recipe_id,
        :freezable,
        :preservation_tip,
        :waste_reduction_tip,
        :cuisine,
        :dietary_needs
      ]

      require_atomic? false
    end

    update :toggle_base_recipe do
      accept []

      change fn changeset, _ ->
        current = Ash.Changeset.get_attribute(changeset, :is_base_recipe)
        Ash.Changeset.change_attribute(changeset, :is_base_recipe, !current)
      end

      require_atomic? false
    end

    update :link_as_follow_up do
      argument :parent_recipe_id, :uuid, allow_nil?: false

      change fn changeset, _ ->
        parent_id = Ash.Changeset.get_argument(changeset, :parent_recipe_id)

        changeset
        |> Ash.Changeset.change_attribute(:is_follow_up, true)
        |> Ash.Changeset.change_attribute(:parent_recipe_id, parent_id)
      end

      require_atomic? false
    end

    update :unlink_from_parent do
      accept []

      change fn changeset, _ ->
        changeset
        |> Ash.Changeset.change_attribute(:is_follow_up, false)
        |> Ash.Changeset.change_attribute(:parent_recipe_id, nil)
      end

      require_atomic? false
    end

    read :favorites do
      filter expr(is_favorite == true)
      prepare build(sort: [name: :asc])
    end

    read :list_all_sorted do
      prepare build(sort: [name: :asc])
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

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :instructions, :string do
      public? true
    end

    attribute :prep_time_minutes, :integer do
      public? true
    end

    attribute :cook_time_minutes, :integer do
      public? true
    end

    attribute :servings, :integer do
      default 4
      public? true
    end

    attribute :difficulty, :atom do
      constraints one_of: [:easy, :medium, :hard]
      default :medium
      public? true
    end

    attribute :image_url, :string do
      public? true
    end

    attribute :source, :string do
      public? true
    end

    attribute :is_favorite, :boolean do
      default false
      public? true
    end

    attribute :is_base_recipe, :boolean do
      default false
      public? true
      description "If true, this recipe is designed to produce leftovers for other meals."
    end

    attribute :is_follow_up, :boolean do
      default false
      public? true
      description "If true, this recipe is designed to use leftovers from a base meal."
    end

    attribute :freezable, :boolean do
      default false
      public? true
    end

    attribute :preservation_tip, :string do
      public? true
    end

    attribute :waste_reduction_tip, :string do
      public? true
    end

    attribute :cuisine, :string do
      public? true
    end

    attribute :dietary_needs, {:array, :atom} do
      public? true
      default []

      constraints items: [
                    one_of: [
                      :vegan,
                      :vegetarian,
                      :pescatarian,
                      :gluten_free,
                      :dairy_free,
                      :nut_free,
                      :halal,
                      :kosher,
                      :keto,
                      :paleo
                    ]
                  ]
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

    has_many :recipe_ingredients, GroceryPlanner.Recipes.RecipeIngredient do
      destination_attribute :recipe_id
    end

    many_to_many :tags, GroceryPlanner.Recipes.RecipeTag do
      through GroceryPlanner.Recipes.RecipeTagging
      source_attribute_on_join_resource :recipe_id
      destination_attribute_on_join_resource :tag_id
    end

    has_many :meal_plans, GroceryPlanner.MealPlanning.MealPlan do
      destination_attribute :recipe_id
    end

    belongs_to :parent_recipe, GroceryPlanner.Recipes.Recipe do
      public? true
      description "The base recipe this recipe is derived from."
    end

    has_many :follow_up_recipes, GroceryPlanner.Recipes.Recipe do
      destination_attribute :parent_recipe_id
    end
  end

  calculations do
    calculate :total_time_minutes, :integer do
      calculation expr(prep_time_minutes + cook_time_minutes)
    end

    calculate :ingredient_availability,
              :decimal,
              GroceryPlanner.Recipes.Calculations.IngredientAvailability do
      description "Percentage of recipe ingredients currently in stock (0.0 to 100.0)"
    end

    calculate :can_make, :boolean, GroceryPlanner.Recipes.Calculations.CanMake do
      description "Whether all required ingredients are currently available in inventory"
    end

    calculate :missing_ingredients,
              {:array, :string},
              GroceryPlanner.Recipes.Calculations.MissingIngredients do
      description "List of ingredient names not currently available in inventory"
    end
  end
end
