defmodule GroceryPlanner.AI.MealOptimizer do
  @moduledoc """
  Meal plan optimization using scoring algorithms.

  Provides recipe suggestions based on:
  - Expiring inventory items (US-001: Optimize My Fridge)
  - Selected ingredients (US-002: Cook With These)
  """

  require Ash.Query

  alias GroceryPlanner.Recipes
  alias GroceryPlanner.Notifications.ExpirationAlerts

  @default_limit 5
  @expiring_days_threshold 7

  @type suggestion :: %{
          recipe: Ash.Resource.record(),
          score: float(),
          expiring_used: [String.t()],
          missing: [String.t()],
          reason: String.t()
        }

  @type ingredient_suggestion :: %{
          recipe: Ash.Resource.record(),
          match_score: float(),
          matched: [String.t()],
          missing: [String.t()]
        }

  @doc """
  Suggests recipes that use expiring ingredients (US-001: Optimize My Fridge).

  Scores each recipe by a weighted combination of:
  - How many expiring ingredients it uses (weighted by urgency)
  - What percentage of ingredients are already in stock
  - How many additional items need to be purchased

  Returns `{:ok, [suggestion]}` or `{:error, reason}`.

  ## Options
  - `:limit` - max suggestions to return (default: 5)
  - `:days_threshold` - days to look ahead for expiring items (default: 7)
  """
  @spec suggest_for_expiring(String.t(), Ash.Resource.record(), keyword()) ::
          {:ok, [suggestion()]} | {:error, term()}
  def suggest_for_expiring(account_id, actor, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    days_threshold = Keyword.get(opts, :days_threshold, @expiring_days_threshold)

    with {:ok, expiring_alerts} <-
           ExpirationAlerts.get_expiring_items(account_id, actor, days_threshold: days_threshold),
         {:ok, recipes} <- load_recipes_with_ingredients(account_id) do
      # Build a map of grocery_item_id => days_until_expiry for scoring
      expiring_entries = flatten_expiring_alerts(expiring_alerts)

      if Enum.empty?(expiring_entries) do
        {:ok, []}
      else
        expiring_map = build_expiring_map(expiring_entries)
        expiring_item_ids = Map.keys(expiring_map)

        suggestions =
          recipes
          |> Enum.map(fn recipe ->
            score_recipe_for_expiring(recipe, expiring_map, expiring_item_ids)
          end)
          |> Enum.filter(fn suggestion -> suggestion.score > 0 end)
          |> Enum.sort_by(fn s -> {-s.score, length(s.missing)} end)
          |> Enum.take(limit)

        {:ok, suggestions}
      end
    end
  end

  @doc """
  Suggests recipes that use the given ingredients (US-002: Cook With These).

  Scores recipes by how many of the selected ingredients they use,
  sorted by match percentage then fewest missing ingredients.

  Returns `{:ok, [ingredient_suggestion]}` or `{:error, reason}`.

  ## Options
  - `:limit` - max suggestions to return (default: 5)
  """
  @spec suggest_for_ingredients(String.t(), [String.t()], Ash.Resource.record(), keyword()) ::
          {:ok, [ingredient_suggestion()]} | {:error, term()}
  def suggest_for_ingredients(account_id, ingredient_ids, _actor, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)

    with {:ok, recipes} <- load_recipes_with_ingredients(account_id),
         {:ok, items} <- load_grocery_items(account_id, ingredient_ids) do
      item_name_map = Map.new(items, fn item -> {item.id, item.name} end)
      ingredient_id_set = MapSet.new(ingredient_ids)

      suggestions =
        recipes
        |> Enum.map(fn recipe ->
          score_recipe_for_ingredients(recipe, ingredient_id_set, item_name_map)
        end)
        |> Enum.filter(fn s -> s.match_score > 0 end)
        |> Enum.sort_by(fn s -> {-s.match_score, length(s.missing)} end)
        |> Enum.take(limit)

      {:ok, suggestions}
    end
  end

  # Private helpers

  defp load_recipes_with_ingredients(account_id) do
    Recipes.list_recipes(
      authorize?: false,
      tenant: account_id,
      query:
        GroceryPlanner.Recipes.Recipe
        |> Ash.Query.load([
          :can_make,
          :missing_ingredients,
          :ingredient_availability,
          recipe_ingredients: [:grocery_item]
        ])
    )
  end

  defp load_grocery_items(account_id, item_ids) do
    # Load specific grocery items by their IDs
    GroceryPlanner.Inventory.GroceryItem
    |> Ash.Query.filter(id in ^item_ids)
    |> Ash.read(authorize?: false, tenant: account_id)
  end

  defp flatten_expiring_alerts(alerts) do
    (alerts.expired ++ alerts.today ++ alerts.tomorrow ++ alerts.this_week)
    |> Enum.uniq_by(& &1.grocery_item_id)
  end

  defp build_expiring_map(entries) do
    # Map grocery_item_id => {days_until_expiry, item_name}
    # Lower days = more urgent
    Map.new(entries, fn entry ->
      days = if is_nil(entry.days_until_expiry), do: 7, else: max(entry.days_until_expiry, 0)

      name =
        if Ash.Resource.loaded?(entry, :grocery_item) && entry.grocery_item,
          do: entry.grocery_item.name,
          else: "Unknown"

      {entry.grocery_item_id, %{days: days, name: name}}
    end)
  end

  defp score_recipe_for_expiring(recipe, expiring_map, expiring_item_ids) do
    # Find which recipe ingredients are expiring
    {expiring_used, _non_expiring} =
      recipe.recipe_ingredients
      |> Enum.reject(& &1.is_optional)
      |> Enum.split_with(fn ri -> ri.grocery_item_id in expiring_item_ids end)

    expiring_names =
      Enum.map(expiring_used, fn ri ->
        case Map.get(expiring_map, ri.grocery_item_id) do
          %{name: name} -> name
          _ -> "Unknown"
        end
      end)

    # Score: urgency-weighted sum for expiring ingredients
    # More urgent (fewer days) = higher score contribution
    expiring_score =
      Enum.reduce(expiring_used, 0.0, fn ri, acc ->
        case Map.get(expiring_map, ri.grocery_item_id) do
          %{days: days} -> acc + 1.0 / max(days, 0.5)
          _ -> acc
        end
      end)

    # Availability bonus (0 to 1) - ingredient_availability is a Decimal (0-100)
    availability =
      case recipe.ingredient_availability do
        %Decimal{} = d -> Decimal.to_float(d) / 100.0
        nil -> 0.0
        val when is_number(val) -> val / 100.0
        _ -> 0.0
      end

    # Missing ingredients (non-optional ones not in stock)
    missing_names = recipe.missing_ingredients || []

    # Shopping penalty
    shopping_penalty = length(missing_names) * 0.2

    # Composite score
    score = expiring_score * 0.5 + availability * 0.3 - shopping_penalty

    reason = build_expiring_reason(length(expiring_used), recipe.can_make, missing_names)

    %{
      recipe: recipe,
      score: score,
      expiring_used: expiring_names,
      missing: missing_names,
      reason: reason
    }
  end

  defp score_recipe_for_ingredients(recipe, ingredient_id_set, item_name_map) do
    required_ingredients =
      recipe.recipe_ingredients
      |> Enum.reject(& &1.is_optional)

    total_required = length(required_ingredients)

    # Count how many of the selected ingredients this recipe uses
    {matched_ingredients, unmatched_ingredients} =
      Enum.split_with(required_ingredients, fn ri ->
        MapSet.member?(ingredient_id_set, ri.grocery_item_id)
      end)

    matched_count = length(matched_ingredients)

    match_score =
      if total_required > 0 do
        matched_count / total_required
      else
        0.0
      end

    matched_names =
      Enum.map(matched_ingredients, fn ri ->
        Map.get(item_name_map, ri.grocery_item_id, "Unknown")
      end)

    missing_names =
      Enum.map(unmatched_ingredients, fn ri ->
        if Ash.Resource.loaded?(ri, :grocery_item) && ri.grocery_item do
          ri.grocery_item.name
        else
          "Unknown"
        end
      end)

    %{
      recipe: recipe,
      match_score: match_score,
      matched: matched_names,
      missing: missing_names
    }
  end

  defp build_expiring_reason(expiring_count, can_make, missing_names) do
    base =
      case expiring_count do
        1 -> "Uses 1 expiring ingredient"
        n -> "Uses #{n} expiring ingredients"
      end

    cond do
      can_make ->
        base <> " - ready to cook!"

      length(missing_names) == 1 ->
        base <> " - just need #{hd(missing_names)}"

      length(missing_names) <= 3 ->
        base <> " - need #{length(missing_names)} more items"

      true ->
        base
    end
  end
end
