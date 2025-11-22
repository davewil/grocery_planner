defmodule GroceryPlanner.Notifications.RecipeSuggestions do
  @moduledoc """
  Functions for suggesting recipes based on expiring ingredients.
  """

  require Ash.Query
  alias GroceryPlanner.Notifications.ExpirationAlerts
  alias GroceryPlanner.Recipes

  @doc """
  Get recipe suggestions based on expiring ingredients.
  Returns recipes ranked by:
  1. Number of expiring ingredients used
  2. Whether all required ingredients are available
  3. Recipe favorite status
  """
  def get_suggestions_for_expiring_items(account_id, actor, opts \\ []) do
    days_threshold = Keyword.get(opts, :days_threshold, 7)
    limit = Keyword.get(opts, :limit, 10)

    # Get all expiring items
    with {:ok, expiring_alerts} <- ExpirationAlerts.get_expiring_items(account_id, actor, days_threshold: days_threshold) do
      # Extract grocery_item_ids from expiring items
      expiring_item_ids =
        (expiring_alerts.expired ++
        expiring_alerts.today ++
        expiring_alerts.tomorrow ++
        expiring_alerts.this_week)
        |> Enum.map(& &1.grocery_item_id)
        |> Enum.uniq()

      if Enum.empty?(expiring_item_ids) do
        {:ok, []}
      else
        # Get all recipes and calculate relevance scores
        {:ok, all_recipes} = Recipes.list_recipes(
          actor: actor,
          tenant: account_id,
          query: GroceryPlanner.Recipes.Recipe
            |> Ash.Query.load([
              :recipe_ingredients,
              :can_make,
              :missing_ingredients,
              :ingredient_availability
            ])
        )

        # Score and rank recipes
        scored_recipes =
          all_recipes
          |> Enum.map(fn recipe ->
            score = calculate_recipe_score(recipe, expiring_item_ids)
            {recipe, score}
          end)
          |> Enum.filter(fn {_recipe, score} -> score > 0 end)
          |> Enum.sort_by(fn {recipe, score} ->
            # Sort by: score (desc), can_make (true first), is_favorite (true first)
            {-score, !recipe.can_make, !recipe.is_favorite}
          end)
          |> Enum.take(limit)
          |> Enum.map(fn {recipe, score} ->
            %{
              recipe: recipe,
              score: score,
              reason: build_suggestion_reason(recipe, score)
            }
          end)

        {:ok, scored_recipes}
      end
    end
  end

  @doc """
  Get a simple list of recipes that can be made with expiring ingredients.
  """
  def get_recipes_using_expiring_items(account_id, actor, opts \\ []) do
    case get_suggestions_for_expiring_items(account_id, actor, opts) do
      {:ok, suggestions} ->
        {:ok, Enum.map(suggestions, & &1.recipe)}

      error -> error
    end
  end

  # Private helpers

  defp calculate_recipe_score(recipe, expiring_item_ids) do
    # Count how many expiring ingredients this recipe uses
    recipe.recipe_ingredients
    |> Enum.filter(fn ingredient ->
      ingredient.grocery_item_id in expiring_item_ids
    end)
    |> length()
  end

  defp build_suggestion_reason(recipe, score) do
    cond do
      score >= 3 && recipe.can_make ->
        "Uses #{score} expiring ingredients - ready to cook!"

      score >= 3 ->
        "Uses #{score} expiring ingredients"

      score == 2 && recipe.can_make ->
        "Uses 2 expiring ingredients - ready to cook!"

      score == 2 ->
        "Uses 2 expiring ingredients"

      score == 1 && recipe.can_make ->
        "Uses 1 expiring ingredient - ready to cook!"

      true ->
        "Uses 1 expiring ingredient"
    end
  end
end
