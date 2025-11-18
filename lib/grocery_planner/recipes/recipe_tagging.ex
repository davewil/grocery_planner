defmodule GroceryPlanner.Recipes.RecipeTagging do
  use Ash.Resource,
    domain: GroceryPlanner.Recipes,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "recipe_taggings"
    repo GroceryPlanner.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:recipe_id, :tag_id]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :recipe_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :tag_id, :uuid do
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
  end

  relationships do
    belongs_to :recipe, GroceryPlanner.Recipes.Recipe do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :tag, GroceryPlanner.Recipes.RecipeTag do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_recipe_tag, [:recipe_id, :tag_id]
  end
end
