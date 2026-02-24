defmodule GroceryPlanner.Onboarding do
  @moduledoc """
  Service for seeding new accounts with starter data, supporting dietary kits and recipe chains.
  """

  alias GroceryPlanner.Onboarding.StarterData
  alias GroceryPlanner.Inventory.{Category, StorageLocation, GroceryItem}
  alias GroceryPlanner.Recipes.{Recipe, RecipeIngredient}
  require Logger

  @doc """
  Seeds a new account with standard categories, locations, items, and recipes.
  Accepts an optional kit_type (default: :omnivore).
  """
  def seed_account(account_id, kit_type \\ :omnivore) do
    Logger.info("Seeding account #{account_id} with #{kit_type || "no"} starter kit...")

    # 1. Seed Categories (always)
    category_map = seed_categories(account_id)

    # 2. Seed Storage Locations (always)
    seed_storage_locations(account_id)

    # 3. Seed Grocery Items & Recipes (only when a kit is selected)
    if kit_type do
      item_map = seed_grocery_items(account_id, category_map, kit_type)
      seed_recipes(account_id, item_map, kit_type)
    end

    Logger.info("Seeding completed for account #{account_id}.")
    :ok
  end

  defp seed_categories(account_id) do
    StarterData.categories()
    |> Enum.reduce(%{}, fn cat_params, acc ->
      params = Map.put(cat_params, :account_id, account_id)

      {:ok, category} =
        Category
        |> Ash.Changeset.for_create(:create, params, tenant: account_id)
        |> Ash.create(authorize?: false)

      Map.put(acc, cat_params.name, category.id)
    end)
  end

  defp seed_storage_locations(account_id) do
    StarterData.locations()
    |> Enum.each(fn loc_params ->
      params = Map.put(loc_params, :account_id, account_id)

      StorageLocation
      |> Ash.Changeset.for_create(:create, params, tenant: account_id)
      |> Ash.create(authorize?: false)
    end)
  end

  defp seed_grocery_items(account_id, category_map, kit_type) do
    items = StarterData.grocery_items(kit_type)

    item_params_list =
      Enum.map(items, fn item_params ->
        category_id = Map.get(category_map, item_params.category, Map.get(category_map, "Pantry"))

        item_params
        |> Map.delete(:category)
        |> Map.put(:category_id, category_id)
        |> Map.put(:account_id, account_id)
      end)

    %{records: records} =
      Ash.bulk_create(
        item_params_list,
        GroceryItem,
        :create,
        tenant: account_id,
        authorize?: false,
        return_records?: true
      )

    Logger.info("Seeded #{Enum.count(records)} grocery items.")

    Enum.reduce(records, %{}, fn item, acc ->
      Map.put(acc, item.name, item.id)
    end)
  end

  defp seed_recipes(account_id, item_map, kit_type) do
    all_recipe_data = StarterData.recipes(kit_type)

    # Process base recipes first so follow-ups can link
    {bases, follow_ups} = Enum.split_with(all_recipe_data, &Map.get(&1, :is_base_recipe, false))

    recipe_map = seed_recipe_batch(account_id, item_map, bases, %{})
    _recipe_map = seed_recipe_batch(account_id, item_map, follow_ups, recipe_map)
  end

  defp seed_recipe_batch(account_id, item_map, recipe_list, recipe_map) do
    Enum.reduce(recipe_list, recipe_map, fn recipe_params, acc ->
      {ingredients, recipe_data} = Map.pop(recipe_params, :ingredients)
      {parent_name, recipe_data} = Map.pop(recipe_data, :parent_recipe_name)

      parent_id = if parent_name, do: Map.get(acc, parent_name)

      # Take all relevant attributes for Recipe
      recipe_attributes = [
        :name,
        :description,
        :instructions,
        :image_url,
        :difficulty,
        :servings,
        :is_base_recipe,
        :is_follow_up,
        :freezable,
        :preservation_tip,
        :waste_reduction_tip
      ]

      params =
        recipe_data
        |> Map.take(recipe_attributes)
        |> Map.put(:account_id, account_id)
        |> Map.put(:parent_recipe_id, parent_id)

      case Recipe
           |> Ash.Changeset.for_create(:create, params, tenant: account_id)
           |> Ash.create(authorize?: false) do
        {:ok, recipe} ->
          seed_recipe_ingredients(account_id, recipe.id, ingredients, item_map)
          Map.put(acc, recipe.name, recipe.id)

        {:error, error} ->
          Logger.error("Failed to seed recipe #{recipe_data.name}: #{inspect(error)}")
          acc
      end
    end)
  end

  defp seed_recipe_ingredients(account_id, recipe_id, ingredients, item_map) do
    ing_params_list =
      ingredients
      |> Enum.map(fn ing_params ->
        item_id = Map.get(item_map, ing_params.item)

        if item_id do
          {qty, unit} = parse_quantity_string(ing_params.quantity)

          ing_params
          |> Map.delete(:item)
          |> Map.put(:recipe_id, recipe_id)
          |> Map.put(:grocery_item_id, item_id)
          |> Map.put(:account_id, account_id)
          |> Map.put(:quantity, qty)
          |> Map.put(:unit, unit || ing_params.unit)
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    Ash.bulk_create(
      ing_params_list,
      RecipeIngredient,
      :create,
      tenant: account_id,
      authorize?: false
    )
  end

  defp parse_quantity_string(nil), do: {nil, nil}
  defp parse_quantity_string(str) when is_integer(str), do: {Decimal.new(str), nil}
  defp parse_quantity_string(str) when is_float(str), do: {Decimal.from_float(str), nil}
  defp parse_quantity_string(%Decimal{} = d), do: {d, nil}

  defp parse_quantity_string(str) when is_binary(str) do
    str = String.trim(str)

    case Regex.run(~r/^(\d+(?:\.\d+)?|\d+\/\d+)/, str) do
      [full_match] ->
        qty = parse_numeric_match(full_match)
        unit = String.trim(String.replace(str, full_match, ""))
        {qty, if(unit == "", do: nil, else: unit)}

      _ ->
        {nil, str}
    end
  end

  defp parse_numeric_match(str) do
    if String.contains?(str, "/") do
      [num, den] = String.split(str, "/")
      Decimal.div(Decimal.new(num), Decimal.new(den))
    else
      Decimal.new(str)
    end
  rescue
    _ -> nil
  end
end
