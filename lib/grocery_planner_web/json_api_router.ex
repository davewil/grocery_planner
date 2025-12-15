defmodule GroceryPlannerWeb.JsonApiRouter do
  use AshJsonApi.Router,
    domains: [
      GroceryPlanner.Inventory,
      GroceryPlanner.Recipes,
      GroceryPlanner.Shopping,
      GroceryPlanner.MealPlanning,
      GroceryPlanner.Notifications,
      GroceryPlanner.Analytics
    ],
    open_api: "/open_api"
end
