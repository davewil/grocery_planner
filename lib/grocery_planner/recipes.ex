defmodule GroceryPlanner.Recipes do
  use Ash.Domain

  resources do
    resource GroceryPlanner.Recipes.RecipeTag do
      define :create_recipe_tag, action: :create, args: [:account_id]
      define :list_recipe_tags, action: :read
      define :get_recipe_tag, action: :read, get_by: [:id]
      define :update_recipe_tag, action: :update
      define :destroy_recipe_tag, action: :destroy
    end

    resource GroceryPlanner.Recipes.Recipe do
      define :create_recipe, action: :create, args: [:account_id]
      define :list_recipes, action: :read
      define :get_recipe, action: :read, get_by: [:id]
      define :update_recipe, action: :update
      define :destroy_recipe, action: :destroy
    end

    resource GroceryPlanner.Recipes.RecipeIngredient do
      define :create_recipe_ingredient, action: :create, args: [:account_id]
      define :list_recipe_ingredients, action: :read
      define :get_recipe_ingredient, action: :read, get_by: [:id]
      define :update_recipe_ingredient, action: :update
      define :destroy_recipe_ingredient, action: :destroy
    end

    resource GroceryPlanner.Recipes.RecipeTagging do
      define :create_recipe_tagging, action: :create
      define :list_recipe_taggings, action: :read
      define :destroy_recipe_tagging, action: :destroy
    end
  end
end
