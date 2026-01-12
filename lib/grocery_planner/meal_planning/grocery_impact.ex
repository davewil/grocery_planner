defmodule GroceryPlanner.MealPlanning.GroceryImpact do
  @moduledoc """
  Calculates the grocery impact of planned meals against current inventory.
  """

  require Ash.Query

  alias GroceryPlanner.Inventory

  def calculate_impact(meal_plans, account_id, actor) do
    # 1. Gather all required ingredients from meal plans

    # 2. Group requirements by Grocery Item and Unit and Scale
    required_totals =
      meal_plans
      |> Enum.reduce(%{}, fn meal_plan, acc ->
        recipe = meal_plan.recipe
        # Scaling factor
        scale =
          if recipe.servings && recipe.servings > 0 do
            Decimal.div(Decimal.new(meal_plan.servings), Decimal.new(recipe.servings))
          else
            Decimal.new(1)
          end

        ingredients = recipe.recipe_ingredients || []

        Enum.reduce(ingredients, acc, fn ingredient, inner_acc ->
          if ingredient.usage_type == :leftover do
            inner_acc
          else
            key = {ingredient.grocery_item_id, ingredient.unit}

            qty =
              if ingredient.quantity do
                Decimal.mult(ingredient.quantity, scale)
              else
                Decimal.new(0)
              end

            Map.update(
              inner_acc,
              key,
              %{
                grocery_item_id: ingredient.grocery_item_id,
                # Might be nil if not loaded
                grocery_item: ingredient.grocery_item,
                quantity: qty,
                unit: ingredient.unit
              },
              fn existing ->
                %{existing | quantity: Decimal.add(existing.quantity, qty)}
              end
            )
          end
        end)
      end)

    # 3. Fetch Inventory
    # We need to know which items we actually need to check.
    needed_item_ids =
      required_totals
      |> Map.keys()
      |> Enum.map(fn {id, _} -> id end)
      |> Enum.uniq()

    inventory_entries =
      if Enum.empty?(needed_item_ids) do
        []
      else
        Inventory.InventoryEntry
        |> Ash.Query.filter(grocery_item_id in ^needed_item_ids)
        |> Ash.Query.filter(status == :available)
        |> Ash.read!(actor: actor, tenant: account_id)
      end

    # Group inventory by item and unit
    inventory_by_item =
      inventory_entries
      |> Enum.reduce(%{}, fn entry, acc ->
        key = {entry.grocery_item_id, entry.unit}
        qty = entry.quantity || Decimal.new(0)

        Map.update(acc, key, qty, &Decimal.add(&1, qty))
      end)

    # 4. Calculate Missing
    required_totals
    |> Enum.map(fn {{item_id, unit}, req_data} ->
      owned_qty = Map.get(inventory_by_item, {item_id, unit}, Decimal.new(0))

      missing_qty = Decimal.sub(req_data.quantity, owned_qty)

      if Decimal.gt?(missing_qty, 0) do
        %{
          grocery_item_id: item_id,
          name: if(req_data.grocery_item, do: req_data.grocery_item.name, else: "Unknown Item"),
          quantity: missing_qty,
          unit: unit,
          owned: owned_qty,
          required: req_data.quantity
        }
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
