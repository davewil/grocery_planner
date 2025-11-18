defmodule GroceryPlanner.Recipes.Calculations.MissingIngredients do
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

      recipe.recipe_ingredients
      |> Enum.reject(fn ingredient ->
        # Don't include optional ingredients in missing list
        if ingredient.is_optional do
          true
        else
          # Load grocery_item and inventory_entries with tenant context
          loaded_ingredient =
            Ash.load!(ingredient, [grocery_item: :inventory_entries],
              tenant: context.tenant,
              authorize?: false
            )

          # Check if available in inventory
          loaded_ingredient.grocery_item.inventory_entries
          |> Enum.any?(fn entry ->
            entry.status == :available && Decimal.compare(entry.quantity, Decimal.new(0)) == :gt
          end)
        end
      end)
      |> Enum.map(fn ingredient ->
        # Load grocery_item name with tenant context
        loaded_ingredient =
          Ash.load!(ingredient, :grocery_item, tenant: context.tenant, authorize?: false)

        loaded_ingredient.grocery_item.name
      end)
    end)
  end
end
