defmodule GroceryPlannerWeb.RecipesLive do
  use GroceryPlannerWeb, :live_view
  import GroceryPlannerWeb.UIComponents

  on_mount {GroceryPlannerWeb.Auth, :require_authenticated_user}

  alias GroceryPlanner.Recipes.Recipe
  alias GroceryPlanner.MealPlanning.Voting

  def mount(_params, _session, socket) do
    voting_active =
      Voting.voting_active?(socket.assigns.current_account.id, socket.assigns.current_user)

    socket =
      socket
      |> assign(:current_scope, socket.assigns.current_account)
      |> assign(:voting_active, voting_active)
      |> assign(:search_query, "")
      |> assign(:show_favorites, false)
      |> assign(:difficulty_filter, nil)
      |> load_recipes()

    {:ok, socket}
  end

  def handle_event("new_recipe", _, socket) do
    {:noreply, push_navigate(socket, to: "/recipes/new")}
  end

  def handle_event("view_recipe", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: "/recipes/#{id}")}
  end

  def handle_event("toggle_favorite", %{"id" => id}, socket) do
    try do
      case GroceryPlanner.Recipes.get_recipe(id,
             actor: socket.assigns.current_user,
             tenant: socket.assigns.current_account.id
           ) do
        {:ok, recipe} ->
          case GroceryPlanner.Recipes.update_recipe(
                 recipe,
                 %{is_favorite: !recipe.is_favorite},
                 actor: socket.assigns.current_user,
                 tenant: socket.assigns.current_account.id
               ) do
            {:ok, _updated_recipe} ->
              {:noreply, load_recipes(socket)}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to update favorite status")}
          end

        _ ->
          {:noreply, put_flash(socket, :error, "Failed to update favorite status")}
      end
    rescue
      _ ->
        {:noreply, put_flash(socket, :error, "Failed to update favorite status")}
    end
  end

  def handle_event("toggle_favorites", _, socket) do
    socket =
      socket
      |> assign(:show_favorites, !socket.assigns.show_favorites)
      |> load_recipes()

    {:noreply, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> load_recipes()

    {:noreply, socket}
  end

  def handle_event("filter_difficulty", %{"value" => difficulty}, socket) do
    difficulty_atom =
      case difficulty do
        "" -> nil
        "easy" -> :easy
        "medium" -> :medium
        "hard" -> :hard
        _ -> nil
      end

    socket =
      socket
      |> assign(:difficulty_filter, difficulty_atom)
      |> load_recipes()

    {:noreply, socket}
  end

  defp load_recipes(socket) do
    account_id = socket.assigns.current_account.id
    user = socket.assigns.current_user

    recipes =
      case GroceryPlanner.Recipes.list_recipes(
             actor: user,
             tenant: account_id,
             query: Recipe |> Ash.Query.sort(name: :asc)
           ) do
        {:ok, all_recipes} ->
          all_recipes
          |> filter_by_favorites(socket.assigns.show_favorites)
          |> filter_by_difficulty(socket.assigns.difficulty_filter)
          |> filter_by_search(socket.assigns.search_query)

        {:error, _} ->
          []
      end

    assign(socket, :recipes, recipes)
  end

  defp filter_by_favorites(recipes, false), do: recipes
  defp filter_by_favorites(recipes, true), do: Enum.filter(recipes, & &1.is_favorite)

  defp filter_by_difficulty(recipes, nil), do: recipes

  defp filter_by_difficulty(recipes, difficulty),
    do: Enum.filter(recipes, &(&1.difficulty == difficulty))

  defp filter_by_search(recipes, ""), do: recipes

  defp filter_by_search(recipes, query) do
    query_lower = String.downcase(query)

    Enum.filter(recipes, fn recipe ->
      String.contains?(String.downcase(recipe.name || ""), query_lower)
    end)
  end
end
