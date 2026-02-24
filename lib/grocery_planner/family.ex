defmodule GroceryPlanner.Family do
  use Ash.Domain

  resources do
    resource GroceryPlanner.Family.FamilyMember do
      define :create_family_member, action: :create, args: [:account_id]
      define :list_family_members, action: :read
      define :get_family_member, action: :read, get_by: [:id]
      define :update_family_member, action: :update
      define :destroy_family_member, action: :destroy
    end

    resource GroceryPlanner.Family.RecipePreference do
      define :set_recipe_preference,
        action: :set_preference,
        args: [:account_id, :family_member_id, :recipe_id]

      define :list_recipe_preferences, action: :read
      define :list_preferences_for_recipe, action: :for_recipe, args: [:recipe_id]
      define :list_preferences_for_recipes, action: :for_recipes, args: [:recipe_ids]

      define :list_preferences_for_member,
        action: :for_family_member,
        args: [:family_member_id]

      define :destroy_recipe_preference, action: :destroy
    end
  end
end
