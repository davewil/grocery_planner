defmodule GroceryPlannerWeb.JsonApiRouter do
  use AshJsonApi.Router,
    domains: [
      GroceryPlanner.Inventory,
      GroceryPlanner.Recipes,
      GroceryPlanner.Shopping
    ],
    open_api: "/open_api"
end
