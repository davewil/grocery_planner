defmodule GroceryPlannerWeb.RecipeSearchLive do
  use GroceryPlannerWeb, :live_view

  on_mount {GroceryPlannerWeb.Auth, :require_authenticated_user}

  alias GroceryPlanner.External
  alias GroceryPlanner.External.RecipeImporter
  alias GroceryPlanner.MealPlanning.Voting

  def mount(_params, _session, socket) do
    voting_active =
      Voting.voting_active?(socket.assigns.current_account.id, socket.assigns.current_user)

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

    case RecipeImporter.import_recipe(external_id, account_id) do
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
end
