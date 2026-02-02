defmodule GroceryPlanner.AI do
  @moduledoc """
  Domain for AI-related resources and operations.
  """
  use Ash.Domain

  resources do
    resource GroceryPlanner.AI.CategorizationFeedback
  end
end
