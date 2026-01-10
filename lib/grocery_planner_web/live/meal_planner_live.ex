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
      |> assign(:meal_planner_layout, resolve_meal_planner_layout(socket.assigns.current_user))
      |> assign(:week_start, week_start)
      |> assign(:days, get_week_days(week_start))
      |> assign(:selected_day, nil)
      |> assign(:show_add_meal_modal, false)
      |> assign(:show_edit_meal_modal, false)
      |> assign(:editing_meal_plan, nil)
      |> assign(:selected_date, nil)
      |> assign(:selected_meal_type, nil)
      |> assign(:available_recipes, [])
      |> assign(:show_chain_suggestion_modal, false)
      |> assign(:chain_suggestion_base_recipe, nil)
      |> assign(:chain_suggestion_follow_ups, [])
      |> assign(:chain_suggestion_slot, nil)
      |> assign(:selected_follow_up_id, nil)
      |> assign(:explorer_search, "")
      |> assign(:explorer_filter, "")
      |> assign(:explorer_difficulty, "")
      |> assign(:explorer_recipes, [])
      |> assign(:explorer_favorite_recipes, [])
      |> assign(:explorer_recent_recipes, [])
      |> assign(:show_explorer_slot_picker, false)
      |> assign(:explorer_picking_recipe, nil)
      |> assign(:explorer_selected_slot, nil)
      |> assign(:explorer_slot_prompt_open, false)
      |> assign(:explorer_slot_prompt_slot, nil)
      |> assign(:explorer_undo, nil)
      |> load_meal_plans()
      |> maybe_load_explorer_recipes()

    {:ok, socket}
  end

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
          |> maybe_load_explorer_recipes()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update layout")}
    end
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
      GroceryPlanner.Recipes.list_recipes_for_meal_planner(
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id
      )

    socket =
      socket
      |> assign(:show_add_meal_modal, true)
      |> assign(:explorer_slot_prompt_open, false)
      |> assign(:explorer_slot_prompt_slot, nil)
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
      |> assign(:explorer_slot_prompt_open, false)
      |> assign(:explorer_slot_prompt_slot, nil)

    {:noreply, socket}
  end

  def handle_event("prevent_close", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("select_recipe", %{"id" => recipe_id}, socket) do
    recipe = Enum.find(socket.assigns.available_recipes, &(&1.id == recipe_id))

    {selected_date, selected_meal_type} =
      case socket.assigns.explorer_slot_prompt_slot do
        %{date: date, meal_type: meal_type} -> {date, meal_type}
        _ -> {socket.assigns.selected_date, socket.assigns.selected_meal_type}
      end

    result =
      GroceryPlanner.MealPlanning.create_meal_plan(
        socket.assigns.current_account.id,
        %{
          recipe_id: recipe_id,
          scheduled_date: selected_date,
          meal_type: selected_meal_type,
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
          |> assign(:explorer_slot_prompt_open, false)
          |> assign(:explorer_slot_prompt_slot, nil)
          |> assign(:selected_date, nil)
          |> assign(:selected_meal_type, nil)
          |> assign(:available_recipes, [])
          |> load_meal_plans()
          |> maybe_show_chain_suggestion(recipe, selected_date, selected_meal_type)
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
           tenant: socket.assigns.current_account.id,
           load: [:recipe]
         ) do
      {:ok, meal_plan} ->
        attrs = %{
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
            socket =
              socket
              |> assign(:explorer_undo, %{action: :remove_meal, attrs: attrs})
              |> load_meal_plans()
              |> put_flash(:info, "Meal removed")

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

  def handle_event("explorer_search", %{"value" => search_term}, socket) do
    socket =
      socket
      |> assign(:explorer_search, search_term)
      |> load_explorer_recipes()

    {:noreply, socket}
  end

  def handle_event("explorer_toggle_favorite", %{"recipe_id" => recipe_id}, socket) do
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
        |> load_explorer_recipes()
        |> put_flash(
          :info,
          if(recipe.is_favorite, do: "Removed from favorites", else: "Added to favorites")
        )

      {:noreply, socket}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Failed to update favorite")}
    end
  end

  def handle_event("explorer_filter", %{"filter" => filter}, socket) do
    socket =
      socket
      |> assign(:explorer_filter, filter)
      |> load_explorer_recipes()

    {:noreply, socket}
  end

  def handle_event("explorer_difficulty", %{"difficulty" => difficulty}, socket) do
    socket =
      socket
      |> assign(:explorer_difficulty, difficulty)
      |> load_explorer_recipes()

    {:noreply, socket}
  end

  def handle_event("explorer_clear_filters", _params, socket) do
    socket =
      socket
      |> assign(:explorer_search, "")
      |> assign(:explorer_filter, "")
      |> assign(:explorer_difficulty, "")
      |> load_explorer_recipes()

    {:noreply, socket}
  end

  def handle_event("explorer_open_slot_picker", %{"recipe_id" => recipe_id} = params, socket) do
    recipe =
      Enum.find(socket.assigns.explorer_recipes, &(&1.id == recipe_id)) ||
        Enum.find(socket.assigns.explorer_recent_recipes, &(&1.id == recipe_id)) ||
        Enum.find(socket.assigns.explorer_favorite_recipes, &(&1.id == recipe_id))

    if is_nil(recipe) do
      {:noreply, put_flash(socket, :error, "Recipe not available")}
    else
      selected_slot =
        cond do
          Map.has_key?(params, "date") and Map.has_key?(params, "meal_type") ->
            %{"date" => params["date"], "meal_type" => params["meal_type"]}

          is_map(socket.assigns.explorer_selected_slot) ->
            socket.assigns.explorer_selected_slot

          true ->
            %{"date" => Date.to_iso8601(Date.utc_today()), "meal_type" => "dinner"}
        end

      socket =
        socket
        |> assign(:show_explorer_slot_picker, true)
        |> assign(:explorer_picking_recipe, recipe)
        |> assign(:explorer_selected_slot, selected_slot)

      {:noreply, socket}
    end
  end

  def handle_event("explorer_close_slot_picker", _params, socket) do
    socket =
      socket
      |> assign(:show_explorer_slot_picker, false)
      |> assign(:explorer_picking_recipe, nil)
      |> assign(:explorer_selected_slot, nil)

    {:noreply, socket}
  end

  def handle_event(
        "explorer_open_recipe_picker",
        %{"date" => date_str, "meal_type" => meal_type},
        socket
      ) do
    date = Date.from_iso8601!(date_str)
    meal_type_atom = String.to_existing_atom(meal_type)

    {:ok, recipes} =
      GroceryPlanner.Recipes.list_recipes_for_meal_planner(
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id
      )

    socket =
      socket
      |> assign(:explorer_selected_slot, %{date: date, meal_type: meal_type_atom})
      |> assign(:explorer_slot_prompt_open, true)
      |> assign(:explorer_slot_prompt_slot, %{date: date, meal_type: meal_type_atom})
      |> assign(:show_add_meal_modal, true)
      |> assign(:selected_date, date)
      |> assign(:selected_meal_type, meal_type_atom)
      |> assign(:available_recipes, recipes)

    {:noreply, socket}
  end

  def handle_event("explorer_select_slot", %{"date" => date, "meal_type" => meal_type}, socket) do
    {:noreply,
     assign(socket, :explorer_selected_slot, %{"date" => date, "meal_type" => meal_type})}
  end

  def handle_event("explorer_confirm_add", _params, socket) do
    %{"date" => date_str, "meal_type" => meal_type_str} = socket.assigns.explorer_selected_slot

    date = Date.from_iso8601!(date_str)
    meal_type = String.to_existing_atom(meal_type_str)

    result =
      GroceryPlanner.MealPlanning.create_meal_plan(
        socket.assigns.current_account.id,
        %{
          recipe_id: socket.assigns.explorer_picking_recipe.id,
          scheduled_date: date,
          meal_type: meal_type,
          servings: 4
        },
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id
      )

    case result do
      {:ok, meal_plan} ->
        socket =
          socket
          |> assign(:show_explorer_slot_picker, false)
          |> assign(:explorer_picking_recipe, nil)
          |> assign(:explorer_selected_slot, nil)
          |> assign(:explorer_undo, %{
            action: :add_meal,
            meal_plan_id: meal_plan.id
          })
          |> load_meal_plans()
          |> put_flash(:info, "Added to plan")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add meal")}
    end
  end

  def handle_event("explorer_quick_add", %{"recipe_id" => recipe_id}, socket) do
    # Backward compatibility: keep event name, but now open the slot picker.
    handle_event("explorer_open_slot_picker", %{"recipe_id" => recipe_id}, socket)
  end

  def handle_event("search_recipes", %{"value" => search_term}, socket) do
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

  def handle_event("copy_from_last_week", _params, socket) do
    week_start = socket.assigns.week_start
    prev_week_start = Date.add(week_start, -7)
    prev_week_end = Date.add(prev_week_start, 6)

    # Get meal plans from previous week
    {:ok, all_meal_plans} =
      GroceryPlanner.MealPlanning.list_meal_plans(
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id,
        load: [:recipe]
      )

    prev_week_plans =
      Enum.filter(all_meal_plans, fn mp ->
        Date.compare(mp.scheduled_date, prev_week_start) in [:eq, :gt] and
          Date.compare(mp.scheduled_date, prev_week_end) in [:eq, :lt]
      end)

    if Enum.empty?(prev_week_plans) do
      {:noreply, put_flash(socket, :error, "No meals found in previous week to copy")}
    else
      # Copy each meal plan to the current week (shift dates by 7 days)
      results =
        Enum.map(prev_week_plans, fn mp ->
          new_date = Date.add(mp.scheduled_date, 7)

          GroceryPlanner.MealPlanning.create_meal_plan(
            socket.assigns.current_account.id,
            %{
              recipe_id: mp.recipe_id,
              scheduled_date: new_date,
              meal_type: mp.meal_type,
              servings: mp.servings,
              notes: mp.notes
            },
            actor: socket.assigns.current_user,
            tenant: socket.assigns.current_account.id
          )
        end)

      successful = Enum.count(results, fn r -> match?({:ok, _}, r) end)

      socket =
        socket
        |> load_meal_plans()
        |> put_flash(
          :info,
          "#{successful} meal#{if successful != 1, do: "s", else: ""} copied from last week"
        )

      {:noreply, socket}
    end
  end

  def handle_event("clear_week", _params, socket) do
    results =
      Enum.map(socket.assigns.meal_plans, fn mp ->
        GroceryPlanner.MealPlanning.destroy_meal_plan(mp,
          actor: socket.assigns.current_user,
          tenant: socket.assigns.current_account.id
        )
      end)

    deleted = Enum.count(results, fn r -> r == :ok end)

    socket =
      socket
      |> load_meal_plans()
      |> put_flash(:info, "#{deleted} meal#{if deleted != 1, do: "s", else: ""} removed")

    {:noreply, socket}
  end

  def handle_event("generate_shopping_list", _params, socket) do
    week_start = socket.assigns.week_start
    week_end = Date.add(week_start, 6)

    planned_meals =
      Enum.filter(socket.assigns.meal_plans, fn mp -> mp.status == :planned end)

    if Enum.empty?(planned_meals) do
      {:noreply, put_flash(socket, :error, "No planned meals found for this week")}
    else
      list_name = "Shopping List - Week of #{Calendar.strftime(week_start, "%B %d, %Y")}"

      case GroceryPlanner.Shopping.generate_shopping_list_from_meal_plans(
             socket.assigns.current_account.id,
             week_start,
             week_end,
             %{
               name: list_name,
               notes: "Auto-generated from meal plan"
             },
             actor: socket.assigns.current_user,
             tenant: socket.assigns.current_account.id
           ) do
        {:ok, _shopping_list} ->
          socket =
            socket
            |> put_flash(
              :info,
              "Shopping list created successfully with smart inventory checking!"
            )
            |> push_navigate(to: ~p"/shopping")

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to generate shopping list")}
      end
    end
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
      case GroceryPlanner.MealPlanning.create_meal_plan(
             socket.assigns.current_account.id,
             %{
               recipe_id: follow_up_id,
               scheduled_date: date,
               meal_type: meal_type,
               servings: 4
             },
             actor: socket.assigns.current_user,
             tenant: socket.assigns.current_account.id
           ) do
        {:ok, _} ->
          socket =
            socket
            |> close_chain_suggestion_modal()
            |> load_meal_plans()
            |> put_flash(:info, "Follow-up meal added")

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to add follow-up meal")}
      end
    end
  end

  def handle_event("dismiss_chain_suggestion", _params, socket) do
    {:noreply, close_chain_suggestion_modal(socket)}
  end

  def handle_event("explorer_undo", _params, socket) do
    case socket.assigns.explorer_undo do
      %{action: :add_meal, meal_plan_id: id} ->
        with {:ok, meal_plan} <-
               GroceryPlanner.MealPlanning.get_meal_plan(
                 id,
                 actor: socket.assigns.current_user,
                 tenant: socket.assigns.current_account.id
               ),
             :ok <-
               GroceryPlanner.MealPlanning.destroy_meal_plan(meal_plan,
                 actor: socket.assigns.current_user,
                 tenant: socket.assigns.current_account.id
               ) do
          socket =
            socket
            |> assign(:explorer_undo, nil)
            |> load_meal_plans()
            |> put_flash(:info, "Undid add")

          {:noreply, socket}
        else
          _ ->
            {:noreply, put_flash(socket, :error, "Could not undo")}
        end

      %{action: :remove_meal, attrs: attrs} ->
        case GroceryPlanner.MealPlanning.create_meal_plan(
               socket.assigns.current_account.id,
               attrs,
               actor: socket.assigns.current_user,
               tenant: socket.assigns.current_account.id
             ) do
          {:ok, _meal_plan} ->
            socket =
              socket
              |> assign(:explorer_undo, nil)
              |> load_meal_plans()
              |> put_flash(:info, "Restored meal")

            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not restore meal")}
        end

      _ ->
        {:noreply, socket}
    end
  end

  defp load_meal_plans(socket) do
    week_start = socket.assigns.week_start
    week_end = Date.add(week_start, 6)

    {:ok, all_meal_plans} =
      GroceryPlanner.MealPlanning.list_meal_plans(
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id,
        load: [:recipe]
      )

    meal_plans =
      Enum.filter(all_meal_plans, fn mp ->
        Date.compare(mp.scheduled_date, week_start) in [:eq, :gt] and
          Date.compare(mp.scheduled_date, week_end) in [:eq, :lt]
      end)

    assign(socket, :meal_plans, meal_plans)
  end

  defp maybe_show_chain_suggestion(socket, nil, _date, _meal_type), do: socket

  defp maybe_show_chain_suggestion(socket, recipe, date, meal_type) do
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

  defp resolve_meal_planner_layout(user) do
    case Map.get(user, :meal_planner_layout) do
      "focus" -> "focus"
      "power" -> "power"
      _ -> "explorer"
    end
  end

  defp maybe_load_explorer_recipes(socket) do
    if socket.assigns.meal_planner_layout == "explorer" do
      load_explorer_recipes(socket)
    else
      socket
    end
  end

  defp load_explorer_recipes(socket) do
    {:ok, all_recipes} =
      GroceryPlanner.Recipes.list_recipes_for_meal_planner(
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id
      )

    socket = assign(socket, :available_recipes, all_recipes)

    search_term = String.trim(socket.assigns.explorer_search || "")
    filter = socket.assigns.explorer_filter || ""
    difficulty = socket.assigns.explorer_difficulty || ""

    recipes =
      all_recipes
      |> maybe_filter_by_search(search_term)
      |> maybe_apply_explorer_filter(filter)
      |> maybe_filter_by_difficulty(difficulty)

    {favorite_recipes, other_recipes} =
      Enum.split_with(recipes, & &1.is_favorite)

    recent_ids = recent_recipe_ids_for_week(socket.assigns.meal_plans)

    recent_recipes =
      recipes
      |> Enum.filter(&(&1.id in recent_ids))
      |> Enum.sort_by(&Enum.find_index(recent_ids, fn id -> id == &1.id end))

    other_recipes =
      other_recipes
      |> Enum.reject(&(&1.id in recent_ids))
      |> Enum.take(24)

    socket
    |> assign(:explorer_favorite_recipes, Enum.take(favorite_recipes, 12))
    |> assign(:explorer_recent_recipes, Enum.take(recent_recipes, 12))
    |> assign(:explorer_recipes, other_recipes)
  end

  defp maybe_filter_by_search(recipes, ""), do: recipes

  defp maybe_filter_by_search(recipes, search_term) do
    search_lower = String.downcase(search_term)

    Enum.filter(recipes, fn recipe ->
      String.contains?(String.downcase(recipe.name), search_lower)
    end)
  end

  defp maybe_apply_explorer_filter(recipes, ""), do: recipes

  defp maybe_apply_explorer_filter(recipes, "quick") do
    Enum.filter(recipes, fn recipe ->
      (recipe.prep_time_minutes || 0) + (recipe.cook_time_minutes || 0) <= 30
    end)
  end

  defp maybe_apply_explorer_filter(recipes, "pantry") do
    # Pantry-first: bias toward recipes with fewer ingredients.
    # This is a pragmatic interpretation until we wire in inventory-aware availability.
    recipes
    |> Enum.sort_by(&length(&1.recipe_ingredients))
    |> Enum.take(24)
  end

  defp maybe_apply_explorer_filter(recipes, _), do: recipes

  defp maybe_filter_by_difficulty(recipes, ""), do: recipes

  defp maybe_filter_by_difficulty(recipes, difficulty)
       when difficulty in ["easy", "medium", "hard"] do
    difficulty_atom = String.to_existing_atom(difficulty)
    Enum.filter(recipes, fn recipe -> recipe.difficulty == difficulty_atom end)
  end

  defp maybe_filter_by_difficulty(recipes, _), do: recipes

  defp recent_recipe_ids_for_week(meal_plans) do
    meal_plans
    |> Enum.sort_by(& &1.scheduled_date, Date)
    |> Enum.map(& &1.recipe_id)
    |> Enum.uniq()
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
