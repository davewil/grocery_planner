defmodule GroceryPlanner.MealPlanning do
  use Ash.Domain

  resources do
    resource GroceryPlanner.MealPlanning.MealPlan
    resource GroceryPlanner.MealPlanning.MealPlanTemplate
    resource GroceryPlanner.MealPlanning.MealPlanTemplateEntry
    resource GroceryPlanner.MealPlanning.MealPlanVoteSession
    resource GroceryPlanner.MealPlanning.MealPlanVoteEntry
  end
end
