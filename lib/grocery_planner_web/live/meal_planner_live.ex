defmodule GroceryPlannerWeb.MealPlannerLive do
  use GroceryPlannerWeb, :live_view
  import GroceryPlannerWeb.UIComponents

  on_mount {GroceryPlannerWeb.Auth, :require_authenticated_user}

  alias GroceryPlanner.MealPlanning.Voting

  def mount(_params, _session, socket) do
    voting_active =
      Voting.voting_active?(socket.assigns.current_account.id, socket.assigns.current_user)

    socket = assign(socket, :current_scope, socket.assigns.current_account)

    today = Date.utc_today()
    week_start = get_week_start(today)

    socket =
      socket
      |> assign(:voting_active, voting_active)
      |> assign(:week_start, week_start)
      |> assign(:days, get_week_days(week_start))
      |> assign(:selected_day, nil)
      |> assign(:show_add_meal_modal, false)
      |> assign(:show_edit_meal_modal, false)
      |> assign(:editing_meal_plan, nil)
      |> assign(:selected_date, nil)
      |> assign(:selected_meal_type, nil)
      |> assign(:available_recipes, [])
      |> load_meal_plans()

    {:ok, socket}
  end

  def handle_event("select_day", %{"date" => date_str}, socket) do
    date = Date.from_iso8601!(date_str)
    {:noreply, assign(socket, :selected_day, date)}
  end

  def handle_event("back_to_week", _params, socket) do
    {:noreply, assign(socket, :selected_day, nil)}
  end

  def handle_event("prev_week", _params, socket) do
    week_start = Date.add(socket.assigns.week_start, -7)

    socket =
      socket
      |> assign(:week_start, week_start)
      |> assign(:days, get_week_days(week_start))
      |> assign(:selected_day, nil)
      |> load_meal_plans()

    {:noreply, socket}
  end

  def handle_event("next_week", _params, socket) do
    week_start = Date.add(socket.assigns.week_start, 7)

    socket =
      socket
      |> assign(:week_start, week_start)
      |> assign(:days, get_week_days(week_start))
      |> assign(:selected_day, nil)
      |> load_meal_plans()

    {:noreply, socket}
  end

  def handle_event("today", _params, socket) do
    today = Date.utc_today()
    week_start = get_week_start(today)

    socket =
      socket
      |> assign(:week_start, week_start)
      |> assign(:days, get_week_days(week_start))
      |> assign(:selected_day, nil)
      |> load_meal_plans()

    {:noreply, socket}
  end

  def handle_event("add_meal", %{"date" => date_str, "meal_type" => meal_type}, socket) do
    date = Date.from_iso8601!(date_str)
    meal_type_atom = String.to_existing_atom(meal_type)

    {:ok, recipes} =
      GroceryPlanner.Recipes.list_recipes(
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id,
        query:
          GroceryPlanner.Recipes.Recipe
          |> Ash.Query.load(:recipe_ingredients)
          |> Ash.Query.sort(name: :asc)
      )

    socket =
      socket
      |> assign(:show_add_meal_modal, true)
      |> assign(:selected_date, date)
      |> assign(:selected_meal_type, meal_type_atom)
      |> assign(:available_recipes, recipes)

    {:noreply, socket}
  end

  def handle_event("close_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_add_meal_modal, false)
      |> assign(:selected_date, nil)
      |> assign(:selected_meal_type, nil)
      |> assign(:available_recipes, [])

    {:noreply, socket}
  end

  def handle_event("prevent_close", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("select_recipe", %{"id" => recipe_id}, socket) do
    result =
      GroceryPlanner.MealPlanning.create_meal_plan(
        socket.assigns.current_account.id,
        %{
          recipe_id: recipe_id,
          scheduled_date: socket.assigns.selected_date,
          meal_type: socket.assigns.selected_meal_type,
          servings: 4
        },
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id
      )

    case result do
      {:ok, _meal_plan} ->
        socket =
          socket
          |> assign(:show_add_meal_modal, false)
          |> assign(:selected_date, nil)
          |> assign(:selected_meal_type, nil)
          |> assign(:available_recipes, [])
          |> load_meal_plans()
          |> put_flash(:info, "Meal added successfully")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add meal")}
    end
  end

  def handle_event("remove_meal", %{"id" => meal_plan_id}, socket) do
    case GroceryPlanner.MealPlanning.get_meal_plan(
           meal_plan_id,
           actor: socket.assigns.current_user,
           tenant: socket.assigns.current_account.id
         ) do
      {:ok, meal_plan} ->
        case GroceryPlanner.MealPlanning.destroy_meal_plan(meal_plan,
               actor: socket.assigns.current_user
             ) do
          :ok ->
            socket =
              socket
              |> load_meal_plans()
              |> put_flash(:info, "Meal removed successfully")

            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to remove meal")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Meal not found")}
    end
  end

  def handle_event("edit_meal", %{"id" => meal_plan_id}, socket) do
    {:ok, meal_plan} =
      GroceryPlanner.MealPlanning.get_meal_plan(
        meal_plan_id,
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id,
        load: [:recipe]
      )

    socket =
      socket
      |> assign(:show_edit_meal_modal, true)
      |> assign(:editing_meal_plan, meal_plan)

    {:noreply, socket}
  end

  def handle_event("close_edit_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_edit_meal_modal, false)
      |> assign(:editing_meal_plan, nil)

    {:noreply, socket}
  end

  def handle_event("update_meal", %{"servings" => servings, "notes" => notes}, socket) do
    result =
      GroceryPlanner.MealPlanning.update_meal_plan(
        socket.assigns.editing_meal_plan,
        %{
          servings: String.to_integer(servings),
          notes: notes
        },
        actor: socket.assigns.current_user
      )

    case result do
      {:ok, _meal_plan} ->
        socket =
          socket
          |> assign(:show_edit_meal_modal, false)
          |> assign(:editing_meal_plan, nil)
          |> load_meal_plans()
          |> put_flash(:info, "Meal updated successfully")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update meal")}
    end
  end

  def handle_event("search_recipes", %{"value" => search_term}, socket) do
    {:ok, all_recipes} =
      GroceryPlanner.Recipes.list_recipes(
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id,
        query:
          GroceryPlanner.Recipes.Recipe
          |> Ash.Query.load(:recipe_ingredients)
          |> Ash.Query.sort(name: :asc)
      )

    recipes =
      if String.trim(search_term) == "" do
        all_recipes
      else
        search_lower = String.downcase(search_term)

        Enum.filter(all_recipes, fn recipe ->
          String.contains?(String.downcase(recipe.name), search_lower)
        end)
      end

    {:noreply, assign(socket, :available_recipes, recipes)}
  end

  defp load_meal_plans(socket) do
    week_start = socket.assigns.week_start
    week_end = Date.add(week_start, 6)

    {:ok, all_meal_plans} =
      GroceryPlanner.MealPlanning.list_meal_plans(
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id,
        query: GroceryPlanner.MealPlanning.MealPlan |> Ash.Query.load(:recipe)
      )

    meal_plans =
      Enum.filter(all_meal_plans, fn mp ->
        Date.compare(mp.scheduled_date, week_start) in [:eq, :gt] and
          Date.compare(mp.scheduled_date, week_end) in [:eq, :lt]
      end)

    assign(socket, :meal_plans, meal_plans)
  end

  defp get_week_start(date) do
    day_of_week = Date.day_of_week(date)
    Date.add(date, -(day_of_week - 1))
  end

  defp get_week_days(week_start) do
    Enum.map(0..6, fn i -> Date.add(week_start, i) end)
  end

  defp get_meal_plan(date, meal_type, meal_plans) do
    Enum.find(meal_plans, fn mp ->
      mp.scheduled_date == date && mp.meal_type == meal_type
    end)
  end

  defp meal_icon(:breakfast), do: "🍳"
  defp meal_icon(:lunch), do: "🥗"
  defp meal_icon(:dinner), do: "🍲"
  defp meal_icon(:snack), do: "🍎"
end
