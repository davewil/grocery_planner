defmodule GroceryPlannerWeb.MealPlannerLive do
  use GroceryPlannerWeb, :live_view
  import GroceryPlannerWeb.UIComponents

  on_mount {GroceryPlannerWeb.Auth, :require_authenticated_user}

  alias GroceryPlanner.MealPlanning.Voting
  alias GroceryPlannerWeb.MealPlannerLive.{DataLoader, Terminology, UndoSystem, UndoActions}
  alias GroceryPlannerWeb.MealPlannerLive.{ExplorerLayout, FocusLayout, PowerLayout}

  def mount(_params, _session, socket) do
    voting_active =
      Voting.voting_active?(socket.assigns.current_account.id, socket.assigns.current_user)

    socket = assign(socket, :current_scope, socket.assigns.current_account)

    today = Date.utc_today()
    week_start = get_week_start(today)

    layout = resolve_meal_planner_layout(socket.assigns.current_user)

    socket =
      socket
      |> assign(:voting_active, voting_active)
      |> assign(:meal_planner_layout, layout)
      |> assign(:week_start, week_start)
      |> assign(:days, get_week_days(week_start))
      |> assign(:selected_day, if(layout == "focus", do: today, else: nil))
      # Shared UI state
      |> assign(:show_add_meal_modal, false)
      |> assign(:show_edit_meal_modal, false)
      |> assign(:editing_meal_plan, nil)
      |> assign(:selected_date, nil)
      |> assign(:selected_meal_type, nil)
      # Populated by DataLoader or specific searches
      |> assign(:available_recipes, [])
      # Chain suggestion state
      |> assign(:show_chain_suggestion_modal, false)
      |> assign(:chain_suggestion_base_recipe, nil)
      |> assign(:chain_suggestion_follow_ups, [])
      |> assign(:chain_suggestion_slot, nil)
      |> assign(:selected_follow_up_id, nil)
      # Initialize Explorer-specific state (used in shared template)
      |> assign(:show_explorer_slot_picker, false)
      |> assign(:explorer_picking_recipe, nil)
      |> assign(:explorer_selected_slot, nil)
      # Undo System
      |> assign(:undo_system, UndoSystem.new())
      # Load data
      |> DataLoader.load_week_meals()
      # Layout specific init
      |> init_layout(layout)

    {:ok, socket}
  end

  # Helper to render the layout from the template
  def render_layout(assigns) do
    case assigns.meal_planner_layout do
      "explorer" -> ExplorerLayout.render(assigns)
      "focus" -> FocusLayout.render(assigns)
      "power" -> PowerLayout.render(assigns)
      _ -> ExplorerLayout.render(assigns)
    end
  end

  # Layout switching
  def handle_event("meal_planner_set_layout", %{"layout" => layout}, socket)
      when layout in ["explorer", "focus", "power"] do
    case GroceryPlanner.Accounts.User.update(socket.assigns.current_user, %{
           meal_planner_layout: layout
         }) do
      {:ok, user} ->
        socket =
          socket
          |> assign(:current_user, user)
          |> assign(:meal_planner_layout, layout)
          |> init_layout(layout)

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update layout")}
    end
  end

  # Shared Navigation
  def handle_event("prev_week", _params, socket) do
    week_start = Date.add(socket.assigns.week_start, -7)
    refresh_week(socket, week_start)
  end

  def handle_event("next_week", _params, socket) do
    week_start = Date.add(socket.assigns.week_start, 7)
    refresh_week(socket, week_start)
  end

  def handle_event("today", _params, socket) do
    today = Date.utc_today()
    week_start = get_week_start(today)

    socket =
      if socket.assigns.meal_planner_layout == "focus" do
        assign(socket, :selected_day, today)
      else
        socket
      end

    refresh_week(socket, week_start)
  end

  # Shared Modal / Add Meal
  def handle_event("add_meal", %{"date" => date_str, "meal_type" => meal_type}, socket) do
    date = Date.from_iso8601!(date_str)
    meal_type_atom = String.to_existing_atom(meal_type)

    socket =
      socket
      # Ensure recipes are loaded for the picker
      |> DataLoader.load_all_recipes()
      |> assign(:show_add_meal_modal, true)
      |> assign(:selected_date, date)
      |> assign(:selected_meal_type, meal_type_atom)
      # Reset explorer specific prompt state if it was lingering
      |> assign(:explorer_slot_prompt_open, false)
      |> assign(:explorer_slot_prompt_slot, nil)

    {:noreply, socket}
  end

  def handle_event("close_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_add_meal_modal, false)
      |> assign(:selected_date, nil)
      |> assign(:selected_meal_type, nil)
      |> assign(:explorer_slot_prompt_open, false)
      |> assign(:explorer_slot_prompt_slot, nil)

    {:noreply, socket}
  end

  def handle_event("prevent_close", _params, socket), do: {:noreply, socket}

  def handle_event("search_recipes", %{"value" => search_term}, socket) do
    # Shared search for the modal
    {:ok, all_recipes} =
      GroceryPlanner.Recipes.list_recipes_for_meal_planner(
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id
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

  def handle_event("select_recipe", %{"id" => recipe_id}, socket) do
    # Determine target slot (explorer prompt vs standard modal)
    {selected_date, selected_meal_type} =
      case socket.assigns[:explorer_slot_prompt_slot] do
        %{date: date, meal_type: meal_type} -> {date, meal_type}
        _ -> {socket.assigns.selected_date, socket.assigns.selected_meal_type}
      end

    perform_add_meal(socket, recipe_id, selected_date, selected_meal_type)
  end

  # Shared Actions
  def handle_event("remove_meal", %{"id" => meal_plan_id}, socket) do
    case GroceryPlanner.MealPlanning.get_meal_plan(
           meal_plan_id,
           actor: socket.assigns.current_user,
           tenant: socket.assigns.current_account.id,
           load: [:recipe]
         ) do
      {:ok, meal_plan} ->
        meal_data = %{
          recipe_id: meal_plan.recipe_id,
          scheduled_date: meal_plan.scheduled_date,
          meal_type: meal_plan.meal_type,
          servings: meal_plan.servings,
          notes: meal_plan.notes,
          status: meal_plan.status
        }

        case GroceryPlanner.MealPlanning.destroy_meal_plan(meal_plan,
               actor: socket.assigns.current_user
             ) do
          :ok ->
            undo_system =
              UndoSystem.push_undo(
                socket.assigns.undo_system,
                UndoActions.delete_meal(meal_data),
                "Meal removed successfully"
              )

            socket =
              socket
              |> assign(:undo_system, undo_system)
              |> DataLoader.load_week_meals()
              # Re-load explorer recipes in case recent list changed
              |> maybe_refresh_layout()

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
    old_attrs = %{
      servings: socket.assigns.editing_meal_plan.servings,
      notes: socket.assigns.editing_meal_plan.notes
    }

    new_attrs = %{
      servings: String.to_integer(servings),
      notes: notes
    }

    result =
      GroceryPlanner.MealPlanning.update_meal_plan(
        socket.assigns.editing_meal_plan,
        new_attrs,
        actor: socket.assigns.current_user
      )

    case result do
      {:ok, meal_plan} ->
        undo_system =
          UndoSystem.push_undo(
            socket.assigns.undo_system,
            UndoActions.update_meal(meal_plan.id, old_attrs, new_attrs),
            "Meal updated successfully"
          )

        socket =
          socket
          |> assign(:undo_system, undo_system)
          |> assign(:show_edit_meal_modal, false)
          |> assign(:editing_meal_plan, nil)
          |> DataLoader.load_week_meals()

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update meal")}
    end
  end

  # Undo Action
  def handle_event("undo", _params, socket) do
    {action, undo_system} = UndoSystem.undo(socket.assigns.undo_system)

    socket = assign(socket, :undo_system, undo_system)

    if action do
      case UndoActions.apply_undo(
             action,
             socket.assigns.current_user,
             socket.assigns.current_account.id
           ) do
        {:ok, _} ->
          socket =
            socket
            |> DataLoader.load_week_meals()
            |> maybe_refresh_layout()

          {:noreply, socket}

        :ok ->
          socket =
            socket
            |> DataLoader.load_week_meals()
            |> maybe_refresh_layout()

          {:noreply, socket}

        _ ->
          {:noreply, put_flash(socket, :error, "Undo failed")}
      end
    else
      {:noreply, socket}
    end
  end

  # Handling Chain Modal Events (Must be here since we kept the logic)
  def handle_event("dismiss_chain_suggestion", _params, socket) do
    {:noreply, close_chain_suggestion_modal(socket)}
  end

  def handle_event("select_follow_up", %{"id" => follow_up_id}, socket) do
    {:noreply, assign(socket, selected_follow_up_id: follow_up_id)}
  end

  def handle_event("accept_chain_suggestion", _params, socket) do
    %{date: date, meal_type: meal_type} = socket.assigns.chain_suggestion_slot

    follow_up_id =
      socket.assigns.selected_follow_up_id ||
        case socket.assigns.chain_suggestion_follow_ups do
          [%{id: id} | _] -> id
          _ -> nil
        end

    if is_nil(follow_up_id) do
      {:noreply, close_chain_suggestion_modal(socket)}
    else
      perform_add_meal(socket, follow_up_id, date, meal_type)
    end
  end

  # Delegate catch-all (Must be last handle_event)
  def handle_event(event, params, socket) do
    # Delegate to the current layout module
    layout_module =
      case socket.assigns.meal_planner_layout do
        "explorer" -> ExplorerLayout
        "focus" -> FocusLayout
        "power" -> PowerLayout
        _ -> ExplorerLayout
      end

    if function_exported?(layout_module, :handle_event, 3) do
      layout_module.handle_event(event, params, socket)
    else
      {:noreply, socket}
    end
  end

  # Messages from Layouts
  def handle_info(
        {:add_meal_internal, %{recipe_id: recipe_id, date: date, meal_type: meal_type}},
        socket
      ) do
    perform_add_meal(socket, recipe_id, date, meal_type)
  end

  def handle_info({:open_add_meal_modal, %{date: date, meal_type: meal_type}}, socket) do
    # We call the handle_event logic
    handle_event(
      "add_meal",
      %{"date" => Date.to_iso8601(date), "meal_type" => to_string(meal_type)},
      socket
    )
  end

  def handle_info({:toggle_favorite, recipe_id}, socket) do
    # This logic was in explorer_toggle_favorite
    with {:ok, recipe} <-
           GroceryPlanner.Recipes.get_recipe(recipe_id,
             actor: socket.assigns.current_user,
             tenant: socket.assigns.current_account.id
           ),
         {:ok, _updated} <-
           GroceryPlanner.Recipes.update_recipe(
             recipe,
             %{is_favorite: !recipe.is_favorite},
             actor: socket.assigns.current_user,
             tenant: socket.assigns.current_account.id
           ) do
      socket =
        socket
        |> maybe_refresh_layout()

      # Note: we should probably refresh the layout recipes list.
      # ExplorerLayout does load_explorer_recipes.

      {:noreply, socket}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Failed to update favorite")}
    end
  end

  # Private Helpers

  defp init_layout(socket, layout) do
    case layout do
      "explorer" -> ExplorerLayout.init(socket)
      "focus" -> FocusLayout.init(socket)
      "power" -> PowerLayout.init(socket)
      _ -> ExplorerLayout.init(socket)
    end
  end

  defp refresh_week(socket, week_start) do
    socket
    |> assign(:week_start, week_start)
    |> assign(:days, get_week_days(week_start))
    |> DataLoader.load_week_meals()
    |> maybe_refresh_layout()
    |> then(&{:noreply, &1})
  end

  defp maybe_refresh_layout(socket) do
    # Re-run init logic for the current layout to refresh lists (e.g. recents)
    init_layout(socket, socket.assigns.meal_planner_layout)
  end

  defp resolve_meal_planner_layout(user) do
    case Map.get(user, :meal_planner_layout) do
      "focus" -> "focus"
      "power" -> "power"
      _ -> "explorer"
    end
  end

  defp get_week_start(date) do
    day_of_week = Date.day_of_week(date)
    Date.add(date, -(day_of_week - 1))
  end

  defp get_week_days(week_start) do
    Enum.map(0..6, fn i -> Date.add(week_start, i) end)
  end

  defp perform_add_meal(socket, recipe_id, date, meal_type) do
    # Logic extracted from select_recipe
    result =
      GroceryPlanner.MealPlanning.create_meal_plan(
        socket.assigns.current_account.id,
        %{
          recipe_id: recipe_id,
          scheduled_date: date,
          meal_type: meal_type,
          servings: 4
        },
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id
      )

    case result do
      {:ok, meal_plan} ->
        undo_system =
          UndoSystem.push_undo(
            socket.assigns.undo_system,
            UndoActions.create_meal(meal_plan.id),
            "Meal added successfully"
          )

        recipe = Enum.find(socket.assigns.available_recipes, &(&1.id == recipe_id))

        socket =
          socket
          |> assign(:undo_system, undo_system)
          |> assign(:show_add_meal_modal, false)
          |> assign(:explorer_slot_prompt_open, false)
          |> assign(:explorer_slot_prompt_slot, nil)
          |> assign(:selected_date, nil)
          |> assign(:selected_meal_type, nil)
          |> DataLoader.load_week_meals()
          |> maybe_refresh_layout()
          |> maybe_show_chain_suggestion(recipe, date, meal_type)

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add meal")}
    end
  end

  # Chain Suggestion Logic (Kept here for now as it uses Modal state)

  defp maybe_show_chain_suggestion(socket, nil, _date, _meal_type), do: socket

  defp maybe_show_chain_suggestion(socket, recipe, date, meal_type) do
    # ... logic from original file ...
    # We need to copy the chain logic helper functions or move them to a helper module
    # For now, I'll assume they are needed and will paste them back.
    follow_ups = chain_follow_up_candidates(recipe)

    if follow_ups == [] do
      socket
    else
      case calculate_suggested_slot(socket, date, meal_type) do
        nil ->
          socket

        slot ->
          socket
          |> assign(:show_chain_suggestion_modal, true)
          |> assign(:chain_suggestion_base_recipe, chain_base_recipe(recipe))
          |> assign(:chain_suggestion_follow_ups, follow_ups)
          |> assign(:chain_suggestion_slot, slot)
          |> assign(:selected_follow_up_id, hd(follow_ups).id)
      end
    end
  end

  # Chain helpers (Private)
  defp chain_base_recipe(%{is_follow_up: true, parent_recipe: parent}) when is_map(parent),
    do: parent

  defp chain_base_recipe(recipe), do: recipe

  defp chain_follow_up_candidates(%{is_base_recipe: true, follow_up_recipes: follow_ups})
       when is_list(follow_ups),
       do: follow_ups

  defp chain_follow_up_candidates(%{
         is_follow_up: true,
         parent_recipe: %{follow_up_recipes: follow_ups}
       })
       when is_list(follow_ups),
       do: follow_ups

  defp chain_follow_up_candidates(
         %{recipe_ingredients: ingredients, parent_recipe: parent} = recipe
       )
       when is_list(ingredients) do
    if Enum.any?(ingredients, &(&1.usage_type == :leftover)) do
      cond do
        recipe.is_base_recipe && is_list(recipe.follow_up_recipes) ->
          recipe.follow_up_recipes

        recipe.is_follow_up && is_map(parent) && is_list(parent.follow_up_recipes) ->
          parent.follow_up_recipes

        true ->
          []
      end
    else
      []
    end
  end

  defp chain_follow_up_candidates(%{recipe_ingredients: ingredients} = recipe)
       when is_list(ingredients) do
    if Enum.any?(ingredients, &(&1.usage_type == :leftover)) do
      cond do
        recipe.is_base_recipe && is_list(recipe.follow_up_recipes) ->
          recipe.follow_up_recipes

        recipe.is_follow_up && is_map(recipe.parent_recipe) &&
            is_list(recipe.parent_recipe.follow_up_recipes) ->
          recipe.parent_recipe.follow_up_recipes

        true ->
          []
      end
    else
      []
    end
  end

  defp chain_follow_up_candidates(_recipe), do: []

  defp calculate_suggested_slot(socket, base_date, base_meal_type) do
    candidates = get_slot_candidates(base_date, base_meal_type)

    Enum.find(candidates, fn {date, meal_type} ->
      not slot_occupied?(socket.assigns.meal_plans, date, meal_type)
    end)
    |> case do
      nil -> nil
      {date, meal_type} -> %{date: date, meal_type: meal_type}
    end
  end

  defp get_slot_candidates(base_date, :breakfast) do
    [
      {base_date, :lunch},
      {base_date, :dinner},
      {Date.add(base_date, 1), :lunch}
    ]
  end

  defp get_slot_candidates(base_date, :lunch) do
    [
      {base_date, :dinner},
      {Date.add(base_date, 1), :lunch},
      {Date.add(base_date, 1), :dinner}
    ]
  end

  defp get_slot_candidates(base_date, :dinner) do
    [
      {Date.add(base_date, 1), :lunch},
      {Date.add(base_date, 1), :dinner}
    ]
  end

  defp get_slot_candidates(base_date, :snack), do: get_slot_candidates(base_date, :lunch)

  defp slot_occupied?(meal_plans, date, meal_type) do
    Enum.any?(meal_plans, fn mp -> mp.scheduled_date == date && mp.meal_type == meal_type end)
  end

  defp close_chain_suggestion_modal(socket) do
    socket
    |> assign(:show_chain_suggestion_modal, false)
    |> assign(:chain_suggestion_base_recipe, nil)
    |> assign(:chain_suggestion_follow_ups, [])
    |> assign(:chain_suggestion_slot, nil)
    |> assign(:selected_follow_up_id, nil)
  end
end
