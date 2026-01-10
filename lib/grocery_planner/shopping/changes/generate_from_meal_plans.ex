defmodule GroceryPlanner.Shopping.Changes.GenerateFromMealPlans do
  @moduledoc false
  use Ash.Resource.Change
  require Ash.Query

  @impl true
  def change(changeset, _opts, context) do
    start_date = Ash.Changeset.get_argument(changeset, :start_date)
    end_date = Ash.Changeset.get_argument(changeset, :end_date)
    account_id = Ash.Changeset.get_argument(changeset, :account_id)

    # Set generated_from to meal_plan and generated_at to now
    changeset
    |> Ash.Changeset.change_attribute(:generated_from, :meal_plan)
    |> Ash.Changeset.change_attribute(:generated_at, DateTime.utc_now())
    |> Ash.Changeset.after_action(fn _changeset, shopping_list ->
      # Generate items after the shopping list is created
      generate_items(shopping_list, start_date, end_date, account_id, context)
      {:ok, shopping_list}
    end)
  end

  defp generate_items(shopping_list, start_date, end_date, account_id, context) do
    {:ok, all_meal_plans} =
      GroceryPlanner.MealPlanning.list_meal_plans(
        actor: context.actor,
        tenant: account_id,
        query:
          GroceryPlanner.MealPlanning.MealPlan
          |> Ash.Query.filter(scheduled_date >= ^start_date and scheduled_date <= ^end_date)
          |> Ash.Query.load(recipe: [recipe_ingredients: :grocery_item])
      )

    meal_plans = Enum.filter(all_meal_plans, fn mp -> mp.status == :planned end)

    ingredient_map = aggregate_ingredients(meal_plans, account_id)

    # Get current inventory
    {:ok, all_inventory} =
      GroceryPlanner.Inventory.list_inventory_entries(
        actor: context.actor,
        tenant: account_id,
        query: GroceryPlanner.Inventory.InventoryEntry |> Ash.Query.load(:grocery_item)
      )

    inventory =
      all_inventory
      |> Enum.filter(fn entry ->
        entry.status == :available && Decimal.compare(entry.quantity, Decimal.new(0)) == :gt
      end)
      |> Enum.group_by(& &1.grocery_item_id)

    Enum.each(ingredient_map, fn {grocery_item_id,
                                  %{quantity: needed_qty, unit: unit, name: name}} ->
      available_qty =
        case Map.get(inventory, grocery_item_id) do
          nil ->
            Decimal.new(0)

          entries ->
            entries
            |> Enum.map(& &1.quantity)
            |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
        end

      shortage = Decimal.sub(needed_qty, available_qty)

      if Decimal.compare(shortage, Decimal.new(0)) == :gt do
        GroceryPlanner.Shopping.ShoppingListItem.create(
          %{
            shopping_list_id: shopping_list.id,
            account_id: account_id,
            grocery_item_id: grocery_item_id,
            name: name,
            quantity: shortage,
            unit: unit
          },
          tenant: account_id,
          actor: context.actor
        )
      end
    end)
  end

  defp aggregate_ingredients(meal_plans, _account_id) do
    meal_plans
    |> Enum.flat_map(fn meal_plan ->
      recipe = meal_plan.recipe

      servings_multiplier =
        Decimal.div(Decimal.new(meal_plan.servings), Decimal.new(recipe.servings))

      Enum.map(recipe.recipe_ingredients, fn ingredient ->
        if !ingredient.is_optional && ingredient.usage_type != :leftover do
          quantity =
            if is_nil(ingredient.quantity) do
              Decimal.new(1)
            else
              Decimal.mult(ingredient.quantity, servings_multiplier)
            end

          %{
            grocery_item_id: ingredient.grocery_item_id,
            quantity: quantity,
            unit: ingredient.unit,
            name: ingredient.grocery_item.name
          }
        end
      end)
      |> Enum.reject(&is_nil/1)
    end)
    |> Enum.group_by(& &1.grocery_item_id)
    |> Enum.map(fn {grocery_item_id, ingredients} ->
      total_quantity =
        ingredients
        |> Enum.map(& &1.quantity)
        |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

      first = List.first(ingredients)

      {grocery_item_id,
       %{
         quantity: total_quantity,
         unit: first.unit,
         name: first.name
       }}
    end)
    |> Map.new()
  end
end
