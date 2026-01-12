defmodule GroceryPlannerWeb.MealPlannerLive.Terminology do
  @moduledoc """
  Consistent terminology across all meal planner layouts.
  """

  def meal_type_label(:breakfast), do: "Breakfast"
  def meal_type_label(:lunch), do: "Lunch"
  def meal_type_label(:dinner), do: "Dinner"
  def meal_type_label(:snack), do: "Snack"
  def meal_type_label(other), do: other |> to_string() |> String.capitalize()

  def meal_type_icon(:breakfast), do: "hero-sun"
  def meal_type_icon(:lunch), do: "hero-cloud-sun"
  def meal_type_icon(:dinner), do: "hero-moon"
  def meal_type_icon(:snack), do: "hero-cake"
  def meal_type_icon(_), do: "hero-clock"

  def action_label(:add), do: "Add"
  def action_label(:swap), do: "Swap"
  def action_label(:clear), do: "Clear"
  def action_label(:edit), do: "Edit"

  def slot_empty_prompt(meal_type), do: "+ Add #{meal_type_label(meal_type)}"

  def layout_name(:explorer), do: "Explorer"
  def layout_name(:focus), do: "Focus"
  def layout_name(:power), do: "Power"
  def layout_name(other), do: other |> to_string() |> String.capitalize()

  def layout_icon(:explorer), do: "hero-squares-2x2"
  def layout_icon(:focus), do: "hero-calendar"
  def layout_icon(:power), do: "hero-view-columns"
  def layout_icon(_), do: "hero-squares-2x2"

  def layout_description(:explorer), do: "Recipe discovery with integrated planning"
  def layout_description(:focus), do: "Day-by-day meal planning"
  def layout_description(:power), do: "Week-at-a-glance kanban board"
  def layout_description(_), do: ""

  def icon_to_emoji("hero-sun"), do: "🍳"
  def icon_to_emoji("hero-cloud-sun"), do: "🥗"
  def icon_to_emoji("hero-moon"), do: "🍲"
  def icon_to_emoji("hero-cake"), do: "🍎"
  def icon_to_emoji(_), do: "🍱"
end
