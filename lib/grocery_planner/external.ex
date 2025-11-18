defmodule GroceryPlanner.External do
  @moduledoc """
  External domain for resources that wrap external APIs.

  These resources use the embedded data layer and don't persist to the database.
  They provide a consistent Ash interface for external data sources.
  """

  use Ash.Domain

  resources do
    resource GroceryPlanner.External.ExternalRecipe do
      define :search_recipes, action: :search, args: [:query]
      define :get_external_recipe, action: :by_id, args: [:id]
      define :random_recipe, action: :random
      define :recipes_by_category, action: :by_category, args: [:category]
    end
  end
end
