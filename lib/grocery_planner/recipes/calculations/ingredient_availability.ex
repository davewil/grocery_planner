defmodule GroceryPlanner.Recipes.Calculations.IngredientAvailability do
  @moduledoc false
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    [:recipe_ingredients]
  end

  @impl true
  def calculate(records, _opts, context) do
    Enum.map(records, fn record ->
      # Load recipe_ingredients with tenant context
      recipe = Ash.load!(record, [:recipe_ingredients], tenant: context.tenant, authorize?: false)
      total_ingredients = length(recipe.recipe_ingredients)

      if total_ingredients == 0 do
        Decimal.new("100.0")
      else
        available_count =
          recipe.recipe_ingredients
          |> Enum.count(fn ingredient ->
            # Load grocery_item and inventory_entries with tenant context
            loaded_ingredient =
              Ash.load!(ingredient, [grocery_item: :inventory_entries],
                tenant: context.tenant,
                authorize?: false
              )

            # Check if there are any available inventory entries
            has_inventory =
              loaded_ingredient.grocery_item.inventory_entries
              |> Enum.any?(fn entry ->
                entry.status == :available &&
                  Decimal.compare(entry.quantity, Decimal.new(0)) == :gt
              end)

            has_inventory
          end)

        # Calculate percentage
        Decimal.div(Decimal.new(available_count), Decimal.new(total_ingredients))
        |> Decimal.mult(Decimal.new("100"))
      end
    end)
  end
end
