defmodule GroceryPlannerWeb.Components.RecipePicker do
  use GroceryPlannerWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:search_query, "")
     |> assign(:filtered_recipes, [])
     |> assign(:favorites, [])
     |> assign(:recent, [])
     |> assign(:show_filters, false)
     |> assign(:filters, %{under_30_min: false, pantry_first: false})
     |> assign(:show_sections, true)
     |> assign(:class, "")}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> load_recipes_if_needed()
      |> filter_recipes()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["recipe-picker h-full flex flex-col bg-base-100", @class]}>
      <!-- Search -->
      <div class="p-3 border-b border-base-200 sticky top-0 bg-base-100 z-10">
        <div class="relative">
          <.icon
            name="hero-magnifying-glass"
            class="w-5 h-5 absolute left-3 top-1/2 -translate-y-1/2 text-base-content/40"
          />
          <input
            type="text"
            placeholder="Search recipes..."
            value={@search_query}
            class="input input-bordered input-sm w-full pl-10"
            phx-keyup="search"
            phx-target={@myself}
            phx-debounce="200"
            name="query"
            autocomplete="off"
          />
        </div>
      </div>
      
    <!-- Filters (optional) -->
      <%= if @show_filters do %>
        <div class="flex gap-2 p-3 border-b border-base-200 overflow-x-auto">
          <button
            class={[
              "btn btn-xs rounded-full",
              @filters.under_30_min && "btn-primary",
              !@filters.under_30_min && "btn-ghost border-base-300"
            ]}
            phx-click="toggle_filter"
            phx-value-filter="under_30_min"
            phx-target={@myself}
          >
            <.icon name="hero-clock" class="w-3 h-3" /> Quick
          </button>
          <button
            class={[
              "btn btn-xs rounded-full",
              @filters.pantry_first && "btn-primary",
              !@filters.pantry_first && "btn-ghost border-base-300"
            ]}
            phx-click="toggle_filter"
            phx-value-filter="pantry_first"
            phx-target={@myself}
          >
            <.icon name="hero-archive-box" class="w-3 h-3" /> Pantry
          </button>
        </div>
      <% end %>
      
    <!-- Recipe Lists -->
      <div class="flex-1 overflow-y-auto p-2 space-y-4">
        <!-- Favorites -->
        <%= if @favorites != [] and @show_sections and @search_query == "" do %>
          <.recipe_section
            title="Favorites"
            icon="hero-heart"
            recipes={@favorites}
            target={@myself}
            on_select="select_recipe"
          />
        <% end %>
        
    <!-- Recently Planned -->
        <%= if @recent != [] and @show_sections and @search_query == "" do %>
          <.recipe_section
            title="Recent"
            icon="hero-clock"
            recipes={@recent}
            target={@myself}
            on_select="select_recipe"
          />
        <% end %>
        
    <!-- Search Results / All Recipes -->
        <.recipe_section
          title={if @search_query != "", do: "Results", else: "All Recipes"}
          icon="hero-book-open"
          recipes={@filtered_recipes}
          target={@myself}
          on_select="select_recipe"
        />
        
    <!-- Empty State -->
        <%= if @filtered_recipes == [] and @favorites == [] do %>
          <div class="p-8 text-center">
            <.icon name="hero-magnifying-glass" class="w-12 h-12 mx-auto text-base-content/30 mb-2" />
            <p class="text-base-content/60">No recipes found</p>
            <%= if @search_query != "" do %>
              <button class="btn btn-ghost btn-sm mt-2" phx-click="clear_search" phx-target={@myself}>
                Clear search
              </button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("search", %{"value" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> filter_recipes()}
  end

  def handle_event("clear_search", _, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> filter_recipes()}
  end

  def handle_event("select_recipe", %{"id" => id}, socket) do
    # We notify the parent LiveView
    send(self(), {:recipe_selected, %{id: id}})
    {:noreply, socket}
  end

  def handle_event("toggle_filter", %{"filter" => filter}, socket) do
    atom_filter = String.to_existing_atom(filter)
    new_filters = Map.update!(socket.assigns.filters, atom_filter, &(!&1))

    {:noreply,
     socket
     |> assign(:filters, new_filters)
     |> filter_recipes()}
  end

  defp load_recipes_if_needed(socket) do
    if socket.assigns[:all_recipes] do
      socket
    else
      # If no recipes passed, we might want to load them? 
      # But usually parent should pass them.
      # For now, let's assume parent passes them or we start empty.
      assign(socket, :all_recipes, [])
    end
  end

  defp filter_recipes(socket) do
    query = String.downcase(socket.assigns.search_query)
    recipes = socket.assigns[:all_recipes] || []

    filtered =
      if query == "" do
        recipes
      else
        Enum.filter(recipes, fn r ->
          String.contains?(String.downcase(r.name), query)
        end)
      end

    # Apply filters (basic stub implementation)
    filtered =
      if socket.assigns.filters.under_30_min do
        Enum.filter(filtered, fn r ->
          (r.total_time_minutes || 0) <= 30
        end)
      else
        filtered
      end

    assign(socket, :filtered_recipes, filtered)
  end

  # Helper components
  defp recipe_section(assigns) do
    ~H"""
    <div>
      <h4 class="text-xs font-bold uppercase tracking-wide text-base-content/60 mb-2 flex items-center gap-1 px-2">
        <.icon name={@icon} class="w-3 h-3" />
        {@title}
      </h4>
      <div class="space-y-1">
        <%= for recipe <- @recipes do %>
          <.picker_recipe_item
            recipe={recipe}
            target={@target}
            on_select={@on_select}
          />
        <% end %>
      </div>
    </div>
    """
  end

  defp picker_recipe_item(assigns) do
    ~H"""
    <button
      class="w-full flex items-center gap-3 p-2 rounded-lg hover:bg-base-200 transition-colors text-left group"
      phx-click={@on_select}
      phx-value-id={@recipe.id}
      phx-target={@target}
    >
      <%= if @recipe.image_url do %>
        <img src={@recipe.image_url} class="w-12 h-12 rounded-lg object-cover bg-base-200" />
      <% else %>
        <div class="w-12 h-12 rounded-lg bg-base-200 flex items-center justify-center">
          <.icon name="hero-photo" class="w-6 h-6 text-base-content/30" />
        </div>
      <% end %>
      <div class="flex-1 min-w-0">
        <p class="font-semibold text-sm truncate text-base-content group-hover:text-primary transition-colors">
          {@recipe.name}
        </p>
        <p class="text-xs text-base-content/60 truncate">
          {@recipe.total_time_minutes || "?"}
          min
          <!-- Stub for ingredient availability -->
          <!-- • 100% Ready -->
        </p>
      </div>
      <%= if @recipe.is_favorite do %>
        <.icon name="hero-heart-solid" class="w-4 h-4 text-warning flex-shrink-0" />
      <% end %>
    </button>
    """
  end
end
