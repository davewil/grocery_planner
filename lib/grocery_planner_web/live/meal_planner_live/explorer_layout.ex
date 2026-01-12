defmodule GroceryPlannerWeb.MealPlannerLive.ExplorerLayout do
  use GroceryPlannerWeb, :html

  import Phoenix.LiveView, only: [put_flash: 3]
  alias GroceryPlannerWeb.MealPlannerLive.{DataLoader, Terminology}
  import GroceryPlannerWeb.CoreComponents

  # Initialize explorer-specific state
  def init(socket) do
    socket
    |> assign(:explorer_search, "")
    |> assign(:explorer_filter, "")
    |> assign(:explorer_difficulty, "")
    |> assign(:explorer_recipes, [])
    |> assign(:explorer_favorite_recipes, [])
    |> assign(:explorer_recent_recipes, [])
    |> assign(:show_explorer_slot_picker, false)
    |> assign(:explorer_picking_recipe, nil)
    |> assign(:explorer_selected_slot, nil)
    # explorer_undo is replaced by global UndoSystem, but we might keep local state if needed
    # for UI feedback, but spec says shared Undo.
    # This loads :available_recipes
    |> DataLoader.load_all_recipes()
    |> load_explorer_recipes()
  end

  def render(assigns) do
    ~H"""
    <div class="grid gap-6 lg:grid-cols-[380px_1fr]">
      <!-- Left Column: Weekly Plan Timeline -->
      <div class="bg-base-100 rounded-2xl shadow-sm border border-base-200 overflow-hidden">
        <div class="p-5 border-b border-base-200 bg-gradient-to-b from-base-100 to-base-200/40">
          <div class="flex items-start justify-between gap-3">
            <div>
              <h2 class="text-lg font-bold text-base-content">Your week</h2>
              <p class="text-sm text-base-content/60">
                Tap a slot, then add from the feed.
              </p>
            </div>
            <div class="flex items-center gap-2">
              <button phx-click="today" class="btn btn-primary btn-sm">Today</button>
            </div>
          </div>

          <div class="mt-4 flex items-center gap-2">
            <button
              phx-click="prev_week"
              class="btn btn-ghost btn-sm"
              title="Previous week"
            >
              <.icon name="hero-chevron-left" class="w-4 h-4" />
            </button>
            <div class="flex-1 text-center text-sm font-semibold text-base-content">
              {Calendar.strftime(@week_start, "%b %d")} – {Calendar.strftime(
                Date.add(@week_start, 6),
                "%b %d"
              )}
            </div>
            <button
              phx-click="next_week"
              class="btn btn-ghost btn-sm"
              title="Next week"
            >
              <.icon name="hero-chevron-right" class="w-4 h-4" />
            </button>
          </div>
        </div>

        <div class="p-4" id="explorer-timeline">
          <div class="space-y-4">
            <%= for day <- @days do %>
              <div class="rounded-xl border border-base-200/80 overflow-hidden">
                <div class={[
                  "px-4 py-3 flex items-center justify-between",
                  if(Date.compare(day, Date.utc_today()) == :eq,
                    do: "bg-primary text-primary-content",
                    else: "bg-base-200 text-base-content"
                  )
                ]}>
                  <div class="font-semibold">
                    {Calendar.strftime(day, "%a")}
                    <span class="opacity-70 font-normal">
                      {Calendar.strftime(day, "%b %d")}
                    </span>
                  </div>
                  <div class="text-xs font-semibold opacity-80">
                    <% meal_count =
                      Enum.count(@meal_plans, fn mp ->
                        mp.scheduled_date == day
                      end) %>
                    <%= if meal_count == 0 do %>
                      No meals
                    <% else %>
                      {meal_count} {if meal_count == 1, do: "meal", else: "meals"}
                    <% end %>
                  </div>
                </div>

                <div class="p-3 grid grid-cols-2 gap-2">
                  <%= for meal_type <- [:breakfast, :lunch, :dinner, :snack] do %>
                    <%= case get_meal_plan(day, meal_type, @week_meals) do %>
                      <% nil -> %>
                        <button
                          phx-click="explorer_open_recipe_picker"
                          phx-value-date={day}
                          phx-value-meal_type={meal_type}
                          class={[
                            "group rounded-xl border border-dashed bg-base-100 transition-all px-3 py-3 text-left",
                            @explorer_selected_slot == %{date: day, meal_type: meal_type} &&
                              "border-primary/50 bg-primary/5 shadow-sm",
                            @explorer_selected_slot != %{date: day, meal_type: meal_type} &&
                              "border-base-300 hover:bg-primary/5 hover:border-primary/40"
                          ]}
                          id={"explorer-slot-#{day}-#{meal_type}"}
                        >
                          <div class="flex items-center justify-between gap-2">
                            <div class="text-sm font-semibold text-base-content capitalize flex items-center gap-2">
                              <span class="text-base">
                                {Terminology.meal_type_icon(meal_type) |> Terminology.icon_to_emoji()}
                              </span>
                              <span>{meal_type}</span>
                            </div>
                            <.icon
                              name="hero-plus"
                              class="w-4 h-4 text-base-content/40 group-hover:text-primary"
                            />
                          </div>
                          <div class="mt-1 text-xs text-base-content/50">Add something</div>
                        </button>
                      <% meal_plan -> %>
                        <button
                          phx-click="edit_meal"
                          phx-value-id={meal_plan.id}
                          class="group rounded-xl border border-base-200 bg-base-100 hover:border-primary/40 hover:shadow-sm transition-all px-3 py-3 text-left"
                          id={"explorer-slot-#{day}-#{meal_type}"}
                          title="Edit meal"
                        >
                          <div class="flex items-center justify-between gap-2">
                            <div class="text-sm font-semibold text-base-content capitalize flex items-center gap-2">
                              <span class="text-base">
                                {Terminology.meal_type_icon(meal_type) |> Terminology.icon_to_emoji()}
                              </span>
                              <span>{meal_type}</span>
                            </div>
                            <.icon
                              name="hero-pencil-square"
                              class="w-4 h-4 text-base-content/40 group-hover:text-primary"
                            />
                          </div>
                          <div class="mt-1 text-xs font-semibold text-base-content truncate">
                            {meal_plan.recipe.name}
                          </div>
                        </button>
                    <% end %>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
      
    <!-- Right Column: Explorer Feed -->
      <div class="bg-base-100 rounded-2xl shadow-sm border border-base-200 overflow-hidden">
        <div class="p-5 border-b border-base-200 bg-gradient-to-b from-base-100 to-base-200/40">
          <div class="flex items-start justify-between gap-4">
            <div>
              <h2 class="text-lg font-bold text-base-content">Explore recipes</h2>
              <p class="text-sm text-base-content/60">
                Discover something new, then add it to your plan.
              </p>
            </div>
            <.link navigate={~p"/recipes/search"} class="btn btn-ghost btn-sm">
              Browse
            </.link>
          </div>

          <div class="mt-4">
            <div class="flex items-center gap-2">
              <div class="relative flex-1">
                <.icon
                  name="hero-magnifying-glass"
                  class="w-5 h-5 absolute left-3 top-1/2 -translate-y-1/2 text-base-content/40"
                />
                <input
                  id="explorer-recipe-search"
                  type="text"
                  name="explorer_search"
                  value={@explorer_search}
                  placeholder="Search recipes..."
                  phx-keyup="explorer_search"
                  phx-debounce="250"
                  class="input w-full pl-10"
                />
              </div>

              <button
                :if={
                  @explorer_search != "" || @explorer_filter not in [nil, ""] ||
                    @explorer_difficulty not in [nil, ""]
                }
                phx-click="explorer_clear_filters"
                class="btn btn-ghost btn-sm whitespace-nowrap"
                id="explorer-clear-filters-top"
                title="Clear Explorer filters"
              >
                <span class="sm:hidden">Clear</span>
                <span class="hidden sm:inline">Clear filters</span>
              </button>
            </div>
          </div>

          <div class="mt-3 flex flex-wrap gap-2">
            <button
              phx-click="explorer_filter"
              phx-value-filter="quick"
              class={[
                "btn btn-sm",
                if(@explorer_filter == "quick", do: "btn-primary", else: "btn-ghost")
              ]}
              id="explorer-filter-quick"
            >
              Under 30 min
            </button>
            <button
              phx-click="explorer_filter"
              phx-value-filter="pantry"
              class={[
                "btn btn-sm",
                if(@explorer_filter == "pantry", do: "btn-primary", else: "btn-ghost")
              ]}
              id="explorer-filter-pantry"
            >
              Pantry-first
            </button>
            <button
              phx-click="explorer_filter"
              phx-value-filter=""
              class={[
                "btn btn-sm",
                if(@explorer_filter in [nil, ""], do: "btn-primary", else: "btn-ghost")
              ]}
              id="explorer-filter-all"
            >
              All
            </button>
          </div>

          <div class="mt-2 flex flex-wrap gap-2">
            <button
              phx-click="explorer_difficulty"
              phx-value-difficulty="easy"
              class={[
                "btn btn-sm",
                if(@explorer_difficulty == "easy", do: "btn-secondary", else: "btn-ghost")
              ]}
              id="explorer-difficulty-easy"
            >
              Easy
            </button>
            <button
              phx-click="explorer_difficulty"
              phx-value-difficulty="medium"
              class={[
                "btn btn-sm",
                if(@explorer_difficulty == "medium", do: "btn-secondary", else: "btn-ghost")
              ]}
              id="explorer-difficulty-medium"
            >
              Medium
            </button>
            <button
              phx-click="explorer_difficulty"
              phx-value-difficulty="hard"
              class={[
                "btn btn-sm",
                if(@explorer_difficulty == "hard", do: "btn-secondary", else: "btn-ghost")
              ]}
              id="explorer-difficulty-hard"
            >
              Hard
            </button>
            <button
              phx-click="explorer_difficulty"
              phx-value-difficulty=""
              class={[
                "btn btn-sm",
                if(@explorer_difficulty in [nil, ""], do: "btn-secondary", else: "btn-ghost")
              ]}
              id="explorer-difficulty-all"
            >
              Any
            </button>
          </div>
        </div>

        <div class="p-4 space-y-8">
          <%= if @explorer_favorite_recipes != [] do %>
            <section aria-labelledby="explorer-favorites-title">
              <div class="flex items-center justify-between gap-3 mb-3">
                <div>
                  <h3
                    id="explorer-favorites-title"
                    class="text-base font-bold text-base-content"
                  >
                    Favorites
                  </h3>
                  <p class="text-sm text-base-content/60">Your go-to dishes, one tap away.</p>
                </div>
              </div>

              <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3" id="explorer-favorites">
                <%= for recipe <- @explorer_favorite_recipes do %>
                  <.explorer_recipe_card recipe={recipe} id_prefix="favorite" />
                <% end %>
              </div>
            </section>
          <% end %>

          <%= if @explorer_recent_recipes != [] do %>
            <section aria-labelledby="explorer-recent-title">
              <div class="flex items-center justify-between gap-3 mb-3">
                <div>
                  <h3 id="explorer-recent-title" class="text-base font-bold text-base-content">
                    Recently planned
                  </h3>
                  <p class="text-sm text-base-content/60">Popular picks from this week.</p>
                </div>
              </div>

              <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3" id="explorer-recents">
                <%= for recipe <- @explorer_recent_recipes do %>
                  <.explorer_recipe_card recipe={recipe} id_prefix="recent" />
                <% end %>
              </div>
            </section>
          <% end %>

          <section aria-labelledby="explorer-all-title">
            <div class="flex items-center justify-between gap-3 mb-3">
              <div>
                <h3 id="explorer-all-title" class="text-base font-bold text-base-content">
                  Explore
                </h3>
                <p class="text-sm text-base-content/60">
                  Fresh ideas to round out your week.
                </p>
              </div>
            </div>

            <%= if @explorer_recipes == [] do %>
              <div class="py-12 text-center">
                <div class="mx-auto w-12 h-12 rounded-2xl bg-base-200 flex items-center justify-center">
                  <.icon name="hero-magnifying-glass" class="w-6 h-6 text-base-content/30" />
                </div>
                <div class="mt-4 font-semibold text-base-content">No recipes found</div>
                <div class="mt-1 text-sm text-base-content/60">
                  Try a different keyword or clear filters.
                </div>
                <button
                  :if={
                    @explorer_search != "" || @explorer_filter not in [nil, ""] ||
                      @explorer_difficulty not in [nil, ""]
                  }
                  phx-click="explorer_clear_filters"
                  class="btn btn-ghost btn-sm mt-4"
                  id="explorer-clear-filters"
                >
                  Clear filters
                </button>
              </div>
            <% else %>
              <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3" id="explorer-feed">
                <%= for recipe <- @explorer_recipes do %>
                  <.explorer_recipe_card recipe={recipe} id_prefix="feed" />
                <% end %>
              </div>
            <% end %>
          </section>
        </div>
      </div>
    </div>
    """
  end

  defp explorer_recipe_card(assigns) do
    assigns = assign_new(assigns, :id_prefix, fn -> "card" end)

    ~H"""
    <div class="group rounded-2xl border border-base-200 bg-base-100 overflow-hidden hover:shadow-md hover:border-primary/30 transition-all">
      <div class="aspect-[4/3] bg-base-200/50 overflow-hidden">
        <%= if @recipe.image_url do %>
          <img
            src={@recipe.image_url}
            alt={@recipe.name}
            class="w-full h-full object-cover group-hover:scale-[1.02] transition-transform duration-300"
          />
        <% else %>
          <div class="w-full h-full flex items-center justify-center">
            <.icon name="hero-photo" class="w-10 h-10 text-base-content/20" />
          </div>
        <% end %>
      </div>

      <div class="p-4">
        <div class="flex items-start justify-between gap-3">
          <h4 class="font-bold text-base-content leading-tight truncate">
            {@recipe.name}
          </h4>

          <button
            phx-click="explorer_toggle_favorite"
            phx-value-recipe_id={@recipe.id}
            class={[
              "p-2 -mr-2 -mt-2 rounded-lg transition-colors",
              @recipe.is_favorite && "text-warning hover:bg-warning/10",
              !@recipe.is_favorite &&
                "text-base-content/30 hover:text-warning hover:bg-warning/10"
            ]}
            title={if @recipe.is_favorite, do: "Unfavorite", else: "Favorite"}
            aria-label={if @recipe.is_favorite, do: "Unfavorite", else: "Favorite"}
            aria-pressed={@recipe.is_favorite}
            id={"explorer-#{@id_prefix}-favorite-toggle-#{@recipe.id}"}
          >
            <.icon name="hero-star" class="w-5 h-5" />
          </button>
        </div>

        <div class="mt-3 flex gap-2">
          <button
            phx-click="explorer_open_slot_picker"
            phx-value-recipe_id={@recipe.id}
            class="btn btn-primary btn-sm flex-1"
            id={"explorer-#{@id_prefix}-add-#{@recipe.id}"}
          >
            <.icon name="hero-plus" class="w-4 h-4" /> Add
          </button>
          <.link
            navigate={~p"/recipes/#{@recipe.id}"}
            class="btn btn-ghost btn-sm"
          >
            Details
          </.link>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("explorer_search", %{"value" => search_term}, socket) do
    socket =
      socket
      |> assign(:explorer_search, search_term)
      |> load_explorer_recipes()

    {:noreply, socket}
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

  def handle_event("explorer_select_slot", %{"date" => date, "meal_type" => meal_type}, socket) do
    {:noreply,
     assign(socket, :explorer_selected_slot, %{"date" => date, "meal_type" => meal_type})}
  end

  def handle_event("explorer_confirm_add", _params, socket) do
    # Delegate to parent LiveView via message for consistency and UndoSystem access
    %{"date" => date_str, "meal_type" => meal_type_str} = socket.assigns.explorer_selected_slot
    recipe_id = socket.assigns.explorer_picking_recipe.id

    send(
      self(),
      {:add_meal_internal,
       %{
         recipe_id: recipe_id,
         date: Date.from_iso8601!(date_str),
         meal_type: String.to_existing_atom(meal_type_str)
       }}
    )

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
    # This event opens the main recipe modal but pre-fills the slot info.
    # The parent LiveView manages the `show_add_meal_modal` state and `selected_date`.
    # We can delegate this to parent or handle it here if we own the state.
    # Currently `MealPlannerLive` owns `show_add_meal_modal`.
    # So we should send a message or let parent handle this event directly?
    # If we delegate all events, this function is called.
    # So we must handle it or delegate back.

    date = Date.from_iso8601!(date_str)
    meal_type_atom = String.to_existing_atom(meal_type)

    send(self(), {:open_add_meal_modal, %{date: date, meal_type: meal_type_atom}})

    # We also update local state to highlight the slot
    socket =
      socket
      |> assign(:explorer_selected_slot, %{date: date, meal_type: meal_type_atom})

    {:noreply, socket}
  end

  def handle_event("explorer_toggle_favorite", %{"recipe_id" => recipe_id}, socket) do
    # This also needs to call backend. Delegate?
    send(self(), {:toggle_favorite, recipe_id})
    {:noreply, socket}
  end

  def handle_event("explorer_quick_add", %{"recipe_id" => recipe_id}, socket) do
    handle_event("explorer_open_slot_picker", %{"recipe_id" => recipe_id}, socket)
  end

  # Helper to load recipes with filters
  defp load_explorer_recipes(socket) do
    all_recipes = socket.assigns.available_recipes

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

    # We might need recent recipe ids here. 
    # NOTE: meal_plans is assigned in DataLoader.load_week_meals which is called in parent.
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

  # Helper for safe map access
  defp get_meal_plan(date, meal_type, week_meals) do
    week_meals
    |> Map.get(date, %{})
    |> Map.get(meal_type)
  end
end
