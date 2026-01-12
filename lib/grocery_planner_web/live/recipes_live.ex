defmodule GroceryPlannerWeb.RecipesLive do
  use GroceryPlannerWeb, :live_view
  import GroceryPlannerWeb.UIComponents

  on_mount {GroceryPlannerWeb.Auth, :require_authenticated_user}

  alias GroceryPlanner.MealPlanning.Voting

  @per_page 12

  def mount(_params, _session, socket) do
    voting_active =
      Voting.voting_active?(socket.assigns.current_account.id, socket.assigns.current_user)

    socket =
      socket
      |> assign(:current_scope, socket.assigns.current_account)
      |> assign(:voting_active, voting_active)
      |> assign(:search_query, "")
      |> assign(:show_favorites, false)
      |> assign(:show_chains, false)
      |> assign(:difficulty_filter, nil)
      |> assign(:sort_by, "name")
      |> assign(:prep_time_filter, nil)
      |> assign(:page, 1)
      |> assign(:per_page, @per_page)
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
      |> assign(:page, 1)
      |> load_recipes()

    {:noreply, socket}
  end

  def handle_event("toggle_chains", _, socket) do
    socket =
      socket
      |> assign(:show_chains, !socket.assigns.show_chains)
      |> assign(:page, 1)
      |> load_recipes()

    {:noreply, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:page, 1)
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
      |> assign(:page, 1)
      |> load_recipes()

    {:noreply, socket}
  end

  def handle_event("sort_by", %{"value" => sort_by}, socket) do
    socket =
      socket
      |> assign(:sort_by, sort_by)
      |> assign(:page, 1)
      |> load_recipes()

    {:noreply, socket}
  end

  def handle_event("filter_prep_time", %{"value" => prep_time}, socket) do
    prep_time_filter =
      case prep_time do
        "" -> nil
        "quick" -> :quick
        "medium" -> :medium
        "long" -> :long
        _ -> nil
      end

    socket =
      socket
      |> assign(:prep_time_filter, prep_time_filter)
      |> assign(:page, 1)
      |> load_recipes()

    {:noreply, socket}
  end

  def handle_event("page", %{"page" => page}, socket) do
    page = String.to_integer(page)

    socket =
      socket
      |> assign(:page, page)
      |> load_recipes()

    {:noreply, socket}
  end

  defp load_recipes(socket) do
    account_id = socket.assigns.current_account.id
    user = socket.assigns.current_user
    page = socket.assigns.page
    per_page = socket.assigns.per_page

    filtered_recipes =
      case GroceryPlanner.Recipes.list_recipes_sorted(
             actor: user,
             tenant: account_id
           ) do
        {:ok, all_recipes} ->
          all_recipes
          |> filter_by_favorites(socket.assigns.show_favorites)
          |> filter_by_chains(socket.assigns.show_chains)
          |> filter_by_difficulty(socket.assigns.difficulty_filter)
          |> filter_by_prep_time(socket.assigns.prep_time_filter)
          |> filter_by_search(socket.assigns.search_query)
          |> sort_recipes(socket.assigns.sort_by)

        {:error, _} ->
          []
      end

    total_count = length(filtered_recipes)
    total_pages = max(1, ceil(total_count / per_page))

    # Paginate
    recipes =
      filtered_recipes
      |> Enum.drop((page - 1) * per_page)
      |> Enum.take(per_page)

    socket
    |> assign(:recipes, recipes)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
  end

  defp filter_by_favorites(recipes, false), do: recipes
  defp filter_by_favorites(recipes, true), do: Enum.filter(recipes, & &1.is_favorite)

  defp filter_by_chains(recipes, false), do: recipes

  defp filter_by_chains(recipes, true),
    do: Enum.filter(recipes, &(&1.is_base_recipe || &1.is_follow_up))

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

  defp filter_by_prep_time(recipes, nil), do: recipes

  defp filter_by_prep_time(recipes, :quick) do
    Enum.filter(recipes, fn recipe ->
      total = (recipe.prep_time_minutes || 0) + (recipe.cook_time_minutes || 0)
      total <= 30
    end)
  end

  defp filter_by_prep_time(recipes, :medium) do
    Enum.filter(recipes, fn recipe ->
      total = (recipe.prep_time_minutes || 0) + (recipe.cook_time_minutes || 0)
      total > 30 && total <= 60
    end)
  end

  defp filter_by_prep_time(recipes, :long) do
    Enum.filter(recipes, fn recipe ->
      total = (recipe.prep_time_minutes || 0) + (recipe.cook_time_minutes || 0)
      total > 60
    end)
  end

  defp sort_recipes(recipes, "name"), do: Enum.sort_by(recipes, & &1.name)

  defp sort_recipes(recipes, "newest"),
    do: Enum.sort_by(recipes, & &1.created_at, {:desc, DateTime})

  defp sort_recipes(recipes, "prep_time") do
    Enum.sort_by(recipes, fn r -> (r.prep_time_minutes || 0) + (r.cook_time_minutes || 0) end)
  end

  defp sort_recipes(recipes, "difficulty") do
    difficulty_order = %{easy: 1, medium: 2, hard: 3}
    Enum.sort_by(recipes, fn r -> Map.get(difficulty_order, r.difficulty, 2) end)
  end

  defp sort_recipes(recipes, _), do: recipes
end
