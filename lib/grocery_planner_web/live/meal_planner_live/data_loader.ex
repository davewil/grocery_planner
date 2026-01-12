defmodule GroceryPlannerWeb.MealPlannerLive.DataLoader do
  @moduledoc """
  Shared data loading functions for all layouts.
  """

  import Phoenix.Component, only: [assign: 3]
  alias GroceryPlanner.{MealPlanning, Recipes}

  def load_week_meals(socket) do
    account_id = socket.assigns.current_account.id
    week_start = socket.assigns.week_start
    week_end = Date.add(week_start, 6)

    # Note: Ideally this should be a filtered query on the resource
    {:ok, all_meal_plans} =
      MealPlanning.list_meal_plans(
        actor: socket.assigns.current_user,
        tenant: account_id,
        load: [recipe: [recipe_ingredients: :grocery_item]]
      )

    meal_plans =
      Enum.filter(all_meal_plans, fn mp ->
        Date.compare(mp.scheduled_date, week_start) in [:eq, :gt] and
          Date.compare(mp.scheduled_date, week_end) in [:eq, :lt]
      end)

    # Assign both the list (for compatibility) and the map (for O(1) access)
    week_meals_map =
      meal_plans
      |> Enum.group_by(& &1.scheduled_date)
      |> Map.new(fn {date, meals} ->
        {date, Enum.into(meals, %{}, &{&1.meal_type, &1})}
      end)

    socket
    |> assign(:meal_plans, meal_plans)
    |> assign(:week_meals, week_meals_map)
    |> compute_shopping_needs()
  end

  def load_favorite_recipes(socket) do
    # Currently reusing the main recipe list logic since we don't have a dedicated endpoint yet
    # This is a placeholder to match the spec's intent
    load_all_recipes(socket)
  end

  def load_recent_recipes(socket, _days \\ 14) do
    # Placeholder: currently recent recipes are derived from meal plans in the LiveView
    socket
  end

  def load_all_recipes(socket, _opts \\ []) do
    {:ok, all_recipes} =
      Recipes.list_recipes_for_meal_planner(
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id
      )

    assign(socket, :available_recipes, all_recipes)
  end

  def compute_shopping_needs(socket) do
    impact =
      GroceryPlanner.MealPlanning.GroceryImpact.calculate_impact(
        socket.assigns.meal_plans,
        socket.assigns.current_account.id,
        socket.assigns.current_user
      )

    assign(socket, :week_shopping_items, impact)
  end

  def compute_day_shopping_needs(socket, date) do
    day_meals =
      socket.assigns.meal_plans
      |> Enum.filter(&(&1.scheduled_date == date))

    impact =
      GroceryPlanner.MealPlanning.GroceryImpact.calculate_impact(
        day_meals,
        socket.assigns.current_account.id,
        socket.assigns.current_user
      )

    assign(socket, :day_shopping_items, impact)
  end
end
