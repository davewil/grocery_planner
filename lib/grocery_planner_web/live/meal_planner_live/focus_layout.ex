defmodule GroceryPlannerWeb.MealPlannerLive.FocusLayout do
  use GroceryPlannerWeb, :html

  alias GroceryPlannerWeb.MealPlannerLive.{Terminology, DataLoader}
  import GroceryPlannerWeb.CoreComponents

  def init(socket) do
    # Ensure selected_day is set, default to today if nil
    selected_day = socket.assigns[:selected_day] || Date.utc_today()

    socket
    |> assign(:selected_day, selected_day)
    |> assign(:show_focus_quick_picker, false)
    |> assign(:focus_picker_slot, nil)
    |> assign(:focus_search_query, "")
    |> DataLoader.compute_day_shopping_needs(selected_day)
  end

  def render(assigns) do
    ~H"""
    <div class="flex h-[calc(100vh-8rem)] lg:h-[calc(100vh-6rem)] overflow-hidden" id="focus-mode">
      <!-- Main Content (Mobile + Desktop Left Col) -->
      <div class="flex-1 flex flex-col min-w-0 bg-base-100/50">
        <!-- Week Strip Header -->
        <div class="flex-none bg-base-100 border-b border-base-200 shadow-sm z-10">
          <div class="px-4 py-3">
            <div class="flex items-center justify-between mb-3">
              <div>
                <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                  Planning
                </div>
                <div class="text-xl font-bold text-base-content flex items-center gap-2">
                  {Calendar.strftime(@selected_day, "%A, %B %d")}
                  <button
                    :if={@selected_day != Date.utc_today()}
                    phx-click="focus_today"
                    class="btn btn-ghost btn-xs text-primary"
                  >
                    Jump to Today
                  </button>
                </div>
              </div>
              <!-- Mobile Shopping Summary (Small) -->
              <div class="lg:hidden flex items-center gap-1 text-sm bg-base-200 px-2 py-1 rounded-lg">
                <.icon name="hero-shopping-cart" class="w-4 h-4" />
                <span class={
                  if Enum.empty?(@day_shopping_items), do: "text-success", else: "text-warning"
                }>
                  {length(@day_shopping_items)}
                </span>
              </div>
            </div>
            
    <!-- Swipeable Week Strip -->
            <div
              class="overflow-x-auto scrollbar-hide -mx-4 px-4 touch-pan-x"
              phx-hook="SwipeableWeek"
              id="week-strip"
            >
              <div class="flex gap-2 min-w-max pb-1">
                <button
                  phx-click="prev_week"
                  class="flex flex-col items-center justify-center w-12 rounded-xl text-base-content/40 hover:bg-base-200 transition-colors"
                >
                  <.icon name="hero-chevron-left" class="w-5 h-5" />
                </button>

                <%= for day <- @days do %>
                  <% selected = @selected_day == day %>
                  <% today = day == Date.utc_today() %>
                  <% meal_count = Enum.count(@week_meals[day] || []) %>
                  <% has_dinner = Map.has_key?(@week_meals[day] || %{}, :dinner) %>

                  <button
                    phx-click="focus_select_day"
                    phx-value-date={day}
                    class={[
                      "flex flex-col items-center py-2 px-1 w-14 rounded-xl transition-all relative",
                      selected && "bg-primary text-primary-content shadow-md scale-105",
                      !selected && today && "bg-primary/10 text-primary border border-primary/20",
                      !selected && !today &&
                        "bg-base-100 border border-base-200 hover:bg-base-200 text-base-content/70"
                    ]}
                    id={"focus-day-#{day}"}
                  >
                    <span class="text-xs opacity-80 uppercase tracking-tighter">
                      {Calendar.strftime(day, "%a")}
                    </span>
                    <span class="text-lg font-bold leading-none my-0.5">
                      {Calendar.strftime(day, "%d")}
                    </span>

                    <div class="flex gap-0.5 mt-1 h-1.5">
                      <%= if meal_count > 0 do %>
                        <div class={[
                          "w-1.5 h-1.5 rounded-full",
                          selected && "bg-primary-content/70",
                          !selected && "bg-primary"
                        ]}>
                        </div>
                      <% end %>
                      <%= if has_dinner do %>
                        <div class={[
                          "w-1.5 h-1.5 rounded-full",
                          selected && "bg-primary-content/70",
                          !selected && "bg-primary"
                        ]}>
                        </div>
                      <% end %>
                    </div>
                  </button>
                <% end %>

                <button
                  phx-click="next_week"
                  class="flex flex-col items-center justify-center w-12 rounded-xl text-base-content/40 hover:bg-base-200 transition-colors"
                >
                  <.icon name="hero-chevron-right" class="w-5 h-5" />
                </button>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Scrollable Meals Area -->
        <div class="flex-1 overflow-y-auto p-4 space-y-4">
          <%= for meal_type <- [:breakfast, :lunch, :dinner, :snack] do %>
            <div>
              <div class="text-xs font-bold uppercase text-base-content/40 mb-2 px-1">
                {meal_type}
              </div>

              <%= case get_meal_plan(@selected_day, meal_type, @week_meals) do %>
                <% nil -> %>
                  <button
                    phx-click="focus_open_picker"
                    phx-value-date={@selected_day}
                    phx-value-meal_type={meal_type}
                    class="w-full py-4 border-2 border-dashed border-base-200 rounded-xl text-base-content/40 hover:border-primary/50 hover:text-primary hover:bg-primary/5 transition-all flex items-center justify-center gap-2 group"
                  >
                    <div class="w-8 h-8 rounded-full bg-base-200 group-hover:bg-primary/20 flex items-center justify-center transition-colors">
                      <.icon name="hero-plus" class="w-4 h-4" />
                    </div>
                    <span class="font-medium">Add {meal_type}</span>
                  </button>
                <% meal_plan -> %>
                  <!-- Swipeable Meal Card -->
                  <div
                    class="relative overflow-hidden rounded-xl group select-none touch-pan-y"
                    phx-hook="SwipeableMeal"
                    id={"focus-meal-#{meal_plan.id}"}
                    data-meal-id={meal_plan.id}
                  >
                    
    <!-- Background Actions (Hidden by default, revealed on swipe) -->
                    <div class="absolute inset-y-0 left-0 w-full bg-error flex items-center justify-start px-6 swipe-action-left opacity-0">
                      <.icon name="hero-trash" class="w-6 h-6 text-error-content" />
                      <span class="text-error-content font-bold ml-2">Remove</span>
                    </div>
                    <div class="absolute inset-y-0 right-0 w-full bg-warning flex items-center justify-end px-6 swipe-action-right opacity-0">
                      <span class="text-warning-content font-bold mr-2">Edit</span>
                      <.icon name="hero-pencil-square" class="w-6 h-6 text-warning-content" />
                    </div>
                    
    <!-- Card Content -->
                    <div class="relative bg-base-100 border border-base-200 p-3 shadow-sm flex gap-3 items-start z-10 transition-transform">
                      <%= if meal_plan.recipe.image_url do %>
                        <img
                          src={meal_plan.recipe.image_url}
                          class="w-20 h-20 rounded-lg object-cover bg-base-200 shrink-0"
                        />
                      <% else %>
                        <div class="w-20 h-20 rounded-lg bg-base-200 flex items-center justify-center shrink-0 text-3xl">
                          {Terminology.meal_type_icon(meal_type) |> Terminology.icon_to_emoji()}
                        </div>
                      <% end %>

                      <div class="flex-1 min-w-0">
                        <div class="flex justify-between items-start">
                          <h3 class="font-bold text-lg truncate leading-tight">
                            {meal_plan.recipe.name}
                          </h3>
                          
    <!-- Context Menu (Desktop mainly) -->
                          <div class="dropdown dropdown-end lg:block hidden">
                            <label tabindex="0" class="btn btn-ghost btn-xs btn-square">
                              <.icon name="hero-ellipsis-horizontal" class="w-5 h-5" />
                            </label>
                            <ul
                              tabindex="0"
                              class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52"
                            >
                              <li>
                                <a phx-click="edit_meal" phx-value-id={meal_plan.id}>Edit Notes</a>
                              </li>
                              <li>
                                <a
                                  phx-click="remove_meal"
                                  phx-value-id={meal_plan.id}
                                  class="text-error"
                                >
                                  Remove
                                </a>
                              </li>
                            </ul>
                          </div>
                        </div>

                        <div class="flex gap-3 text-sm text-base-content/60 mt-1">
                          <span>{meal_plan.servings} servings</span>
                          <span>•</span>
                          <span>{meal_plan.recipe.total_time_minutes || 30}m</span>
                        </div>

                        <%= if meal_plan.notes do %>
                          <div class="mt-2 text-sm bg-warning/10 text-warning-content px-2 py-1 rounded inline-block">
                            <.icon
                              name="hero-chat-bubble-bottom-center-text"
                              class="w-3 h-3 inline mr-1"
                            />
                            {meal_plan.notes}
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </div>
              <% end %>
            </div>
          <% end %>

          <div class="h-20"></div>
          <!-- Bottom padding -->
        </div>
      </div>
      
    <!-- Desktop Sidebar (Grocery Impact) -->
      <div class="hidden lg:flex flex-col w-96 border-l border-base-200 bg-base-100/30">
        <div class="p-6">
          <h3 class="font-bold text-lg mb-4 flex items-center gap-2">
            <.icon name="hero-shopping-cart" class="w-5 h-5" /> Grocery Impact
          </h3>
          
    <!-- Day Summary -->
          <div class="card bg-base-100 shadow-sm border border-base-200 mb-6">
            <div class="card-body p-4">
              <h4 class="text-sm font-bold uppercase text-base-content/60 mb-2">
                Needed for {Calendar.strftime(@selected_day, "%A")}
              </h4>

              <%= if Enum.empty?(@day_shopping_items) do %>
                <div class="flex items-center gap-2 text-success py-2">
                  <.icon name="hero-check-circle" class="w-6 h-6" />
                  <span class="font-medium">All ingredients in stock!</span>
                </div>
              <% else %>
                <ul class="space-y-2 max-h-60 overflow-y-auto pr-2">
                  <%= for item <- @day_shopping_items do %>
                    <li class="flex items-center justify-between text-sm group">
                      <div class="flex items-center gap-2">
                        <div class="w-1.5 h-1.5 rounded-full bg-warning"></div>
                        <span>{item.name}</span>
                      </div>
                      <span class="font-mono text-base-content/60">
                        {Decimal.round(item.quantity, 1)} {item.unit}
                      </span>
                    </li>
                  <% end %>
                </ul>
                <div class="mt-3 pt-3 border-t border-base-200 text-xs text-center text-base-content/50">
                  Based on your current inventory
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Week Summary -->
          <div class="card bg-base-100 shadow-sm border border-base-200">
            <div class="card-body p-4">
              <h4 class="text-sm font-bold uppercase text-base-content/60 mb-2">Week Overview</h4>
              <div class="stats stats-vertical shadow-none bg-transparent">
                <div class="stat p-2 pl-0">
                  <div class="stat-title">Items to Buy</div>
                  <div class="stat-value text-primary text-2xl">
                    {length(@week_shopping_items || [])}
                  </div>
                  <div class="stat-desc">For whole week</div>
                </div>
                <div class="stat p-2 pl-0">
                  <div class="stat-title">Meals Planned</div>
                  <div class="stat-value text-secondary text-2xl">{Enum.count(@meal_plans)}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Quick Picker Bottom Sheet -->
      <%= if @show_focus_quick_picker do %>
        <div
          class="fixed inset-0 z-50 flex items-end justify-center sm:items-center"
          phx-click="focus_close_picker"
        >
          <!-- Backdrop -->
          <div class="absolute inset-0 bg-neutral/60 backdrop-blur-sm animate-in fade-in"></div>
          
    <!-- Sheet -->
          <div
            class="relative w-full max-w-lg bg-base-100 rounded-t-2xl sm:rounded-2xl shadow-2xl overflow-hidden animate-in slide-in-from-bottom duration-300 max-h-[85vh] flex flex-col"
            phx-click="prevent_close_picker"
          >
            
    <!-- Handle -->
            <div class="w-full flex justify-center pt-3 pb-1 sm:hidden">
              <div class="w-12 h-1.5 bg-base-300 rounded-full"></div>
            </div>
            
    <!-- Header -->
            <div class="p-4 border-b border-base-200">
              <h3 class="font-bold text-lg">
                Add {String.capitalize(to_string(@focus_picker_slot.meal_type))}
              </h3>
              <p class="text-sm text-base-content/60">
                {Calendar.strftime(@focus_picker_slot.date, "%A, %B %d")}
              </p>
              
    <!-- Search -->
              <div class="mt-4 relative">
                <.icon
                  name="hero-magnifying-glass"
                  class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-base-content/40"
                />
                <input
                  type="text"
                  placeholder="Search recipes..."
                  class="input input-bordered w-full pl-10"
                  phx-keyup="focus_search_recipes"
                  phx-debounce="300"
                  value={@focus_search_query}
                  autofocus
                />
              </div>
            </div>
            
    <!-- List -->
            <div class="overflow-y-auto flex-1 p-2 space-y-2">
              <%= if @available_recipes == [] do %>
                <div class="text-center py-10 text-base-content/40">
                  <p>No recipes found</p>
                </div>
              <% end %>

              <%= for recipe <- @available_recipes do %>
                <button
                  class="w-full flex items-center gap-3 p-2 hover:bg-base-200 rounded-xl transition-colors text-left group"
                  phx-click="focus_select_recipe"
                  phx-value-id={recipe.id}
                >
                  <%= if recipe.image_url do %>
                    <img src={recipe.image_url} class="w-14 h-14 rounded-lg object-cover bg-base-200" />
                  <% else %>
                    <div class="w-14 h-14 rounded-lg bg-base-200 flex items-center justify-center text-2xl">
                      <.icon name="hero-book-open" class="w-6 h-6 text-base-content/20" />
                    </div>
                  <% end %>

                  <div class="flex-1 min-w-0">
                    <div class="font-bold truncate">{recipe.name}</div>
                    <div class="text-xs text-base-content/60 flex items-center gap-2">
                      <span>{recipe.total_time_minutes || "--"}m</span>
                      <%= if recipe.is_favorite do %>
                        <.icon name="hero-heart-solid" class="w-3 h-3 text-error" />
                      <% end %>
                    </div>
                  </div>

                  <div class="opacity-0 group-hover:opacity-100 transition-opacity">
                    <.icon name="hero-plus-circle" class="w-6 h-6 text-primary" />
                  </div>
                </button>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("focus_prev_day", _params, socket) do
    date = (socket.assigns.selected_day || Date.utc_today()) |> Date.add(-1)

    socket
    |> assign(:selected_day, date)
    |> DataLoader.compute_day_shopping_needs(date)
    |> then(&{:noreply, &1})
  end

  def handle_event("focus_next_day", _params, socket) do
    date = (socket.assigns.selected_day || Date.utc_today()) |> Date.add(1)

    socket
    |> assign(:selected_day, date)
    |> DataLoader.compute_day_shopping_needs(date)
    |> then(&{:noreply, &1})
  end

  def handle_event("focus_today", _params, socket) do
    date = Date.utc_today()

    socket
    |> assign(:selected_day, date)
    |> DataLoader.compute_day_shopping_needs(date)
    |> then(&{:noreply, &1})
  end

  def handle_event("focus_select_day", %{"date" => date_str}, socket) do
    date = Date.from_iso8601!(date_str)

    socket
    |> assign(:selected_day, date)
    |> DataLoader.compute_day_shopping_needs(date)
    |> then(&{:noreply, &1})
  end

  # Picker Events
  def handle_event("focus_open_picker", %{"date" => date_str, "meal_type" => meal_type}, socket) do
    date = Date.from_iso8601!(date_str)
    atom_meal_type = String.to_existing_atom(meal_type)

    socket
    # Helper from DataLoader
    |> DataLoader.load_all_recipes()
    |> assign(:show_focus_quick_picker, true)
    |> assign(:focus_picker_slot, %{date: date, meal_type: atom_meal_type})
    |> assign(:focus_search_query, "")
    |> then(&{:noreply, &1})
  end

  def handle_event("focus_close_picker", _params, socket) do
    {:noreply, assign(socket, :show_focus_quick_picker, false)}
  end

  def handle_event("prevent_close_picker", _params, socket), do: {:noreply, socket}

  def handle_event("focus_search_recipes", %{"value" => query}, socket) do
    # Delegate to parent's search logic but update our local filtered list
    # Actually, DataLoader.load_all_recipes loads everything into :available_recipes.
    # We can filter locally or call the parent's search.
    # Parent has "search_recipes" which updates :available_recipes.
    # We can just reuse that logic by manually filtering or calling the resource again?
    # The parent handle_event("search_recipes") does a DB query.
    # Let's just do an in-memory filter if available_recipes is already loaded, or DB query.
    # For consistency, let's call the same logic.

    # We'll just invoke the search logic similar to the parent
    {:ok, all_recipes} =
      GroceryPlanner.Recipes.list_recipes_for_meal_planner(
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id
      )

    recipes =
      if String.trim(query) == "" do
        all_recipes
      else
        search_lower = String.downcase(query)

        Enum.filter(all_recipes, fn recipe ->
          String.contains?(String.downcase(recipe.name), search_lower)
        end)
      end

    socket
    |> assign(:available_recipes, recipes)
    |> assign(:focus_search_query, query)
    |> then(&{:noreply, &1})
  end

  def handle_event("focus_select_recipe", %{"id" => recipe_id}, socket) do
    %{date: date, meal_type: meal_type} = socket.assigns.focus_picker_slot

    # Send message to parent to add meal
    send(self(), {:add_meal_internal, %{recipe_id: recipe_id, date: date, meal_type: meal_type}})

    {:noreply, assign(socket, :show_focus_quick_picker, false)}
  end

  # Helper for safe map access (same as before)
  defp get_meal_plan(date, meal_type, week_meals) do
    week_meals
    |> Map.get(date, %{})
    |> Map.get(meal_type)
  end
end
