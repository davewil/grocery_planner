defmodule GroceryPlannerWeb.RecipeSearchLive do
  use GroceryPlannerWeb, :live_view

  on_mount {GroceryPlannerWeb.Auth, :require_authenticated_user}

  alias GroceryPlanner.External
  alias GroceryPlanner.External.TheMealDB
  alias GroceryPlanner.MealPlanning.Voting

  def mount(_params, _session, socket) do
    voting_active = Voting.voting_active?(socket.assigns.current_account.id, socket.assigns.current_user)

    socket =
      socket
      |> assign(:current_scope, socket.assigns.current_account)
      |> assign(:voting_active, voting_active)
      |> assign(:search_query, "")
      |> assign(:results, [])
      |> assign(:loading, false)
      |> assign(:searched, false)
      |> assign(:error, nil)

    {:ok, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:loading, true)
      |> assign(:searched, true)
      |> assign(:error, nil)

    send(self(), {:perform_search, query})

    {:noreply, socket}
  end

  def handle_event("random", _, socket) do
    socket =
      socket
      |> assign(:loading, true)
      |> assign(:error, nil)

    send(self(), :get_random)

    {:noreply, socket}
  end

  def handle_event("import", %{"id" => external_id}, socket) do
    account_id = socket.assigns.current_account.id

    case import_recipe(external_id, account_id) do
      {:ok, recipe} ->
        socket =
          socket
          |> put_flash(:info, "Recipe imported successfully!")
          |> push_navigate(to: "/recipes/#{recipe.id}")

        {:noreply, socket}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to import recipe. It may already exist.")}
    end
  end

  def handle_info({:perform_search, query}, socket) do
    case External.search_recipes(query) do
      {:ok, results} ->
        socket =
          socket
          |> assign(:results, results)
          |> assign(:loading, false)

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:results, [])
          |> assign(:loading, false)
          |> assign(:error, "Failed to search: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  def handle_info(:get_random, socket) do
    case External.random_recipe() do
      {:ok, meal} ->
        socket =
          socket
          |> assign(:results, [meal])
          |> assign(:loading, false)
          |> assign(:searched, true)

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:results, [])
          |> assign(:loading, false)
          |> assign(:error, "Failed to get random meal: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  defp import_recipe(external_id, account_id) do
    with {:ok, meal} <- External.get_external_recipe(external_id),
         recipe_attrs <- TheMealDB.to_recipe_attrs(Map.from_struct(meal)),
         {:ok, recipe} <-
           GroceryPlanner.Recipes.create_recipe(
             account_id,
             recipe_attrs,
             authorize?: false,
             tenant: account_id
           ),
         :ok <- import_ingredients(meal.ingredients, recipe.id, account_id) do
      {:ok, recipe}
    end
  end

  defp import_ingredients(ingredients, recipe_id, account_id) do
    ingredients
    |> Enum.with_index(1)
    |> Enum.each(fn {ingredient, index} ->
      with {:ok, grocery_item} <- find_or_create_grocery_item(ingredient.name, account_id),
           {quantity, unit} <- parse_measure(ingredient.measure) do
        GroceryPlanner.Recipes.create_recipe_ingredient(
          account_id,
          %{
            recipe_id: recipe_id,
            grocery_item_id: grocery_item.id,
            quantity: quantity,
            unit: unit,
            sort_order: index
          },
          authorize?: false,
          tenant: account_id
        )
      end
    end)

    :ok
  end

  defp find_or_create_grocery_item(item_name, account_id) do
    # Try to find existing grocery item by name
    case GroceryPlanner.Inventory.list_grocery_items(tenant: account_id) do
      {:ok, items} ->
        case Enum.find(items, fn item ->
               String.downcase(item.name) == String.downcase(item_name)
             end) do
          nil ->
            # Create new grocery item
            GroceryPlanner.Inventory.create_grocery_item(
              account_id,
              %{name: item_name},
              authorize?: false,
              tenant: account_id
            )

          item ->
            {:ok, item}
        end

      error ->
        error
    end
  end

  defp parse_measure(measure) when is_binary(measure) do
    # Try to extract quantity from the measure string
    # Examples: "1 cup", "2 tbsp", "1.5 kg", "3"
    case Regex.run(~r/^(\d+\.?\d*)\s*(.*)$/, String.trim(measure)) do
      [_, qty_str, unit] ->
        {String.to_float(qty_str <> if(String.contains?(qty_str, "."), do: "", else: ".0")),
         String.trim(unit)}

      _ ->
        # If no number found, default to 1 with the whole measure as unit
        {1.0, measure}
    end
  end

  defp parse_measure(_), do: {1.0, ""}
end
