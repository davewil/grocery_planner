# MP-000: Meal Planner Shared Infrastructure

## Overview

**Feature:** Cross-cutting infrastructure for all meal planner layout modes
**Priority:** High (Prerequisite for all modes)
**Estimated Effort:** 3-4 days

## Problem Statement

The three meal planner layouts (Explorer, Focus, Power) share common functionality that must be implemented consistently. Without a shared foundation, each mode would duplicate logic and create maintenance burden.

## Shared Requirements

### 1. Layout Switching System
### 2. Recipe Picker Surface
### 3. Undo/Toast System
### 4. Loading & Skeleton States
### 5. Consistent Terminology
### 6. User Preference Persistence

## Technical Specification

### 1. Layout Switching System

#### User Preference Storage

```elixir
# In User resource
defmodule GroceryPlanner.Accounts.User do
  # ...existing code...

  attributes do
    # ...existing attributes...
    attribute :meal_planner_layout, :atom do
      constraints one_of: [:explorer, :focus, :power]
      default :explorer
      allow_nil? false
    end
  end
end
```

#### Migration

```elixir
defmodule GroceryPlanner.Repo.Migrations.AddMealPlannerLayoutToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :meal_planner_layout, :string, default: "explorer", null: false
    end
  end
end
```

#### LiveView Layout Dispatcher

```elixir
defmodule GroceryPlannerWeb.MealPlannerLive do
  use GroceryPlannerWeb, :live_view

  alias GroceryPlannerWeb.MealPlannerLive.{ExplorerLayout, FocusLayout, PowerLayout}

  @impl true
  def mount(params, session, socket) do
    user = socket.assigns.current_user
    layout = determine_layout(params, user)

    socket =
      socket
      |> assign(:layout, layout)
      |> assign_common_data()
      |> apply_layout_assigns(layout)

    {:ok, socket}
  end

  defp determine_layout(params, user) do
    # URL param takes precedence (for testing/switching)
    case params["layout"] do
      "explorer" -> :explorer
      "focus" -> :focus
      "power" -> :power
      _ -> user.meal_planner_layout || :explorer
    end
  end

  defp assign_common_data(socket) do
    socket
    |> assign(:week_start, week_start(Date.utc_today()))
    |> assign(:selected_date, Date.utc_today())
    |> load_week_meals()
  end

  defp apply_layout_assigns(socket, :explorer), do: ExplorerLayout.init(socket)
  defp apply_layout_assigns(socket, :focus), do: FocusLayout.init(socket)
  defp apply_layout_assigns(socket, :power), do: PowerLayout.init(socket)

  @impl true
  def render(assigns) do
    case assigns.layout do
      :explorer -> ExplorerLayout.render(assigns)
      :focus -> FocusLayout.render(assigns)
      :power -> PowerLayout.render(assigns)
    end
  end

  # Delegate events to appropriate layout module
  @impl true
  def handle_event(event, params, socket) do
    case socket.assigns.layout do
      :explorer -> ExplorerLayout.handle_event(event, params, socket)
      :focus -> FocusLayout.handle_event(event, params, socket)
      :power -> PowerLayout.handle_event(event, params, socket)
    end
  end
end
```

#### In-App Layout Switcher Component

```heex
<div class="dropdown dropdown-end">
  <label tabindex="0" class="btn btn-ghost btn-sm gap-1">
    <.icon name={layout_icon(@layout)} class="w-4 h-4" />
    <span class="hidden sm:inline"><%= layout_name(@layout) %></span>
    <.icon name="hero-chevron-down" class="w-3 h-3" />
  </label>
  <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box shadow-lg w-56 z-50">
    <li class="menu-title">Planner Layout</li>
    <li>
      <button phx-click="switch_layout" phx-value-layout="explorer" class={if @layout == :explorer, do: "active"}>
        <.icon name="hero-squares-2x2" class="w-4 h-4" />
        <div>
          <span class="font-medium">Explorer</span>
          <span class="text-xs text-base-content/60 block">Discover & plan together</span>
        </div>
      </button>
    </li>
    <li>
      <button phx-click="switch_layout" phx-value-layout="focus" class={if @layout == :focus, do: "active"}>
        <.icon name="hero-calendar" class="w-4 h-4" />
        <div>
          <span class="font-medium">Focus</span>
          <span class="text-xs text-base-content/60 block">Day-by-day planning</span>
        </div>
      </button>
    </li>
    <li>
      <button phx-click="switch_layout" phx-value-layout="power" class={if @layout == :power, do: "active"}>
        <.icon name="hero-view-columns" class="w-4 h-4" />
        <div>
          <span class="font-medium">Power</span>
          <span class="text-xs text-base-content/60 block">Week-at-a-glance board</span>
        </div>
      </button>
    </li>
    <li class="menu-title mt-2">
      <span class="text-xs">
        <.icon name="hero-cog-6-tooth" class="w-3 h-3 inline" />
        Change default in Settings
      </span>
    </li>
  </ul>
</div>
```

#### Switch Layout Handler

```elixir
def handle_event("switch_layout", %{"layout" => layout_str}, socket) do
  layout = String.to_existing_atom(layout_str)

  # Update user preference in database
  socket.assigns.current_user
  |> Ash.Changeset.for_update(:update_layout_preference, %{meal_planner_layout: layout})
  |> Ash.update()

  # Re-initialize with new layout
  socket =
    socket
    |> assign(:layout, layout)
    |> apply_layout_assigns(layout)

  {:noreply, socket}
end
```

### 2. Shared Recipe Picker Surface

A reusable component that can be rendered as a modal (Explorer), bottom sheet (Focus), or sidebar (Power).

```elixir
defmodule GroceryPlannerWeb.Components.RecipePicker do
  use GroceryPlannerWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
      socket
      |> assign(:search_query, "")
      |> assign(:filtered_recipes, [])
      |> assign(:favorites, [])
      |> assign(:recent, [])}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> load_recipes_if_needed()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["recipe-picker", @class]}>
      <!-- Search -->
      <div class="p-3 border-b border-base-300">
        <input
          type="text"
          placeholder="Search recipes..."
          value={@search_query}
          class="input input-bordered input-sm w-full"
          phx-change="search"
          phx-target={@myself}
          phx-debounce="200"
          name="query"
        />
      </div>

      <!-- Filters (optional) -->
      <%= if @show_filters do %>
        <div class="flex gap-2 p-3 border-b border-base-300 overflow-x-auto">
          <.filter_chip
            active={@filters.under_30_min}
            phx-click="toggle_filter"
            phx-value-filter="under_30_min"
            phx-target={@myself}
          >
            <.icon name="hero-clock" class="w-3 h-3" /> Quick
          </.filter_chip>
          <.filter_chip
            active={@filters.pantry_first}
            phx-click="toggle_filter"
            phx-value-filter="pantry_first"
            phx-target={@myself}
          >
            <.icon name="hero-archive-box" class="w-3 h-3" /> Pantry
          </.filter_chip>
        </div>
      <% end %>

      <!-- Recipe Lists -->
      <div class="flex-1 overflow-y-auto">
        <!-- Favorites -->
        <%= if @favorites != [] and @show_sections do %>
          <.recipe_section title="Favorites" icon="hero-heart" recipes={@favorites} target={@myself} on_select={@on_select} />
        <% end %>

        <!-- Recently Planned -->
        <%= if @recent != [] and @show_sections do %>
          <.recipe_section title="Recent" icon="hero-clock" recipes={@recent} target={@myself} on_select={@on_select} />
        <% end %>

        <!-- Search Results / All Recipes -->
        <.recipe_section
          title={if @search_query != "", do: "Results", else: "All Recipes"}
          recipes={@filtered_recipes}
          target={@myself}
          on_select={@on_select}
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
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply,
      socket
      |> assign(:search_query, query)
      |> filter_recipes()}
  end

  def handle_event("select_recipe", %{"id" => id}, socket) do
    recipe = Enum.find(socket.assigns.all_recipes, &(&1.id == id))
    send(self(), {:recipe_selected, recipe})
    {:noreply, socket}
  end

  # Helper components
  defp recipe_section(assigns) do
    ~H"""
    <div class="p-3">
      <h4 class="text-xs font-semibold uppercase text-base-content/60 mb-2 flex items-center gap-1">
        <.icon name={@icon} class="w-3 h-3" />
        <%= @title %>
      </h4>
      <div class={@list_class || "space-y-1"}>
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
      class="w-full flex items-center gap-3 p-2 rounded-lg hover:bg-base-200 transition-colors text-left"
      phx-click={@on_select}
      phx-value-id={@recipe.id}
      phx-target={@target}
    >
      <%= if @recipe.image_url do %>
        <img src={@recipe.image_url} class="w-10 h-10 rounded object-cover" />
      <% else %>
        <div class="w-10 h-10 rounded bg-base-300 flex items-center justify-center">
          <.icon name="hero-photo" class="w-5 h-5 text-base-content/30" />
        </div>
      <% end %>
      <div class="flex-1 min-w-0">
        <p class="font-medium text-sm truncate"><%= @recipe.name %></p>
        <p class="text-xs text-base-content/60">
          <%= @recipe.total_time_minutes %> min •
          <%= if @recipe.can_make, do: "Ready", else: "#{trunc(@recipe.ingredient_availability)}%" %>
        </p>
      </div>
      <%= if @recipe.is_favorite do %>
        <.icon name="hero-heart-solid" class="w-4 h-4 text-error flex-shrink-0" />
      <% end %>
    </button>
    """
  end
end
```

### 3. Undo/Toast System

```elixir
defmodule GroceryPlannerWeb.MealPlannerLive.UndoSystem do
  @max_stack_size 20

  defstruct [:undo_stack, :redo_stack, :toast]

  def new do
    %__MODULE__{
      undo_stack: [],
      redo_stack: [],
      toast: nil
    }
  end

  def push_undo(system, action, message) do
    %{system |
      undo_stack: Enum.take([action | system.undo_stack], @max_stack_size),
      redo_stack: [],
      toast: %{message: message, action: :undo, expires_at: now_plus(5)}
    }
  end

  def undo(system) do
    case system.undo_stack do
      [] -> {nil, system}
      [action | rest] ->
        {action, %{system |
          undo_stack: rest,
          redo_stack: Enum.take([action | system.redo_stack], @max_stack_size),
          toast: %{message: "Action undone", action: nil, expires_at: now_plus(3)}
        }}
    end
  end

  def redo(system) do
    case system.redo_stack do
      [] -> {nil, system}
      [action | rest] ->
        {action, %{system |
          redo_stack: rest,
          undo_stack: Enum.take([action | system.undo_stack], @max_stack_size),
          toast: %{message: "Action redone", action: nil, expires_at: now_plus(3)}
        }}
    end
  end

  def clear_toast(system), do: %{system | toast: nil}

  defp now_plus(seconds), do: DateTime.add(DateTime.utc_now(), seconds)
end

# Undo action types
defmodule GroceryPlannerWeb.MealPlannerLive.UndoActions do
  def create_meal(meal_id), do: {:create_meal, meal_id}
  def delete_meal(meal_data), do: {:delete_meal, meal_data}
  def move_meal(meal_id, from, to), do: {:move_meal, meal_id, from, to}
  def update_meal(meal_id, old_attrs, new_attrs), do: {:update_meal, meal_id, old_attrs, new_attrs}

  def apply_undo({:create_meal, meal_id}) do
    # Delete the created meal
    MealPlanning.delete_meal_plan!(meal_id)
  end

  def apply_undo({:delete_meal, meal_data}) do
    # Recreate the deleted meal
    MealPlanning.create_meal_plan!(meal_data)
  end

  def apply_undo({:move_meal, meal_id, from, _to}) do
    # Move back to original position
    MealPlanning.update_meal_plan!(meal_id, %{
      scheduled_date: from.date,
      meal_type: from.meal_type
    })
  end

  def apply_undo({:update_meal, meal_id, old_attrs, _new_attrs}) do
    # Restore old attributes
    MealPlanning.update_meal_plan!(meal_id, old_attrs)
  end
end
```

#### Toast Component

```heex
<div :if={@undo_system.toast} class="toast toast-end z-50">
  <div class="alert shadow-lg">
    <span><%= @undo_system.toast.message %></span>
    <%= if @undo_system.toast.action == :undo do %>
      <button class="btn btn-sm btn-ghost" phx-click="undo">
        Undo
      </button>
    <% end %>
  </div>
</div>
```

### 4. Loading & Skeleton States

```elixir
defmodule GroceryPlannerWeb.Components.Skeletons do
  use Phoenix.Component

  def recipe_card_skeleton(assigns) do
    ~H"""
    <div class="card bg-base-100 animate-pulse">
      <figure class="aspect-[4/3] bg-base-300"></figure>
      <div class="card-body p-3">
        <div class="h-4 bg-base-300 rounded w-3/4"></div>
        <div class="h-3 bg-base-300 rounded w-1/2 mt-2"></div>
      </div>
    </div>
    """
  end

  def meal_slot_skeleton(assigns) do
    ~H"""
    <div class="bg-base-200 rounded-lg p-4 animate-pulse">
      <div class="flex items-center gap-3">
        <div class="w-12 h-12 bg-base-300 rounded-lg"></div>
        <div class="flex-1">
          <div class="h-4 bg-base-300 rounded w-3/4 mb-2"></div>
          <div class="h-3 bg-base-300 rounded w-1/2"></div>
        </div>
      </div>
    </div>
    """
  end

  def day_column_skeleton(assigns) do
    ~H"""
    <div class="flex-1 min-w-[120px] border-r border-base-300 animate-pulse">
      <div class="p-2 text-center border-b border-base-300 bg-base-200">
        <div class="h-3 bg-base-300 rounded w-8 mx-auto mb-1"></div>
        <div class="h-5 bg-base-300 rounded w-6 mx-auto"></div>
      </div>
      <div class="p-2 space-y-2">
        <%= for _ <- 1..4 do %>
          <div class="h-16 bg-base-300 rounded-lg"></div>
        <% end %>
      </div>
    </div>
    """
  end
end
```

### 5. Consistent Terminology

Create a terminology module to ensure consistency:

```elixir
defmodule GroceryPlannerWeb.MealPlannerLive.Terminology do
  @moduledoc """
  Consistent terminology across all meal planner layouts.
  """

  def meal_type_label(:breakfast), do: "Breakfast"
  def meal_type_label(:lunch), do: "Lunch"
  def meal_type_label(:dinner), do: "Dinner"
  def meal_type_label(:snack), do: "Snack"

  def meal_type_icon(:breakfast), do: "hero-sun"
  def meal_type_icon(:lunch), do: "hero-cloud-sun"
  def meal_type_icon(:dinner), do: "hero-moon"
  def meal_type_icon(:snack), do: "hero-cake"

  def action_label(:add), do: "Add"
  def action_label(:swap), do: "Swap"
  def action_label(:clear), do: "Clear"
  def action_label(:edit), do: "Edit"

  def slot_empty_prompt(meal_type), do: "+ Add #{meal_type_label(meal_type)}"

  def layout_name(:explorer), do: "Explorer"
  def layout_name(:focus), do: "Focus"
  def layout_name(:power), do: "Power"

  def layout_icon(:explorer), do: "hero-squares-2x2"
  def layout_icon(:focus), do: "hero-calendar"
  def layout_icon(:power), do: "hero-view-columns"

  def layout_description(:explorer), do: "Recipe discovery with integrated planning"
  def layout_description(:focus), do: "Day-by-day meal planning"
  def layout_description(:power), do: "Week-at-a-glance kanban board"
end
```

### 6. Shared Data Loading

```elixir
defmodule GroceryPlannerWeb.MealPlannerLive.DataLoader do
  @moduledoc """
  Shared data loading functions for all layouts.
  """

  alias GroceryPlanner.{MealPlanning, Recipes}

  def load_week_meals(socket) do
    account_id = socket.assigns.current_account.id
    week_start = socket.assigns.week_start

    meals =
      MealPlanning.list_meal_plans_for_week(account_id, week_start)
      |> Enum.group_by(& &1.scheduled_date)
      |> Map.new(fn {date, meals} ->
        {date, Enum.into(meals, %{}, &{&1.meal_type, &1})}
      end)

    assign(socket, :week_meals, meals)
  end

  def load_favorite_recipes(socket) do
    account_id = socket.assigns.current_account.id
    favorites = Recipes.list_favorite_recipes(account_id, limit: 10)
    assign(socket, :favorites, favorites)
  end

  def load_recent_recipes(socket, days \\ 14) do
    account_id = socket.assigns.current_account.id
    recent = MealPlanning.list_recently_planned_recipes(account_id, days)
    assign(socket, :recent_recipes, recent)
  end

  def load_all_recipes(socket, opts \\ []) do
    account_id = socket.assigns.current_account.id
    recipes = Recipes.list_recipes_for_planning(account_id, opts)
    assign(socket, :recipes, recipes)
  end

  def compute_shopping_needs(socket) do
    week_meals = socket.assigns.week_meals
    account_id = socket.assigns.current_account.id

    recipes = week_meals
      |> Map.values()
      |> Enum.flat_map(&Map.values/1)
      |> Enum.map(& &1.recipe)

    missing = MealPlanning.compute_missing_ingredients(recipes, account_id)
    assign(socket, :week_shopping_items, missing)
  end
end
```

## Settings Page Integration

Add layout preference to the Settings page:

```heex
<!-- In settings_live.ex -->
<.section title="Meal Planner">
  <div class="form-control">
    <label class="label">
      <span class="label-text font-medium">Default Layout</span>
    </label>
    <select
      class="select select-bordered"
      name="user[meal_planner_layout]"
      phx-change="update_layout_preference"
    >
      <%= for layout <- [:explorer, :focus, :power] do %>
        <option value={layout} selected={@current_user.meal_planner_layout == layout}>
          <%= Terminology.layout_name(layout) %> - <%= Terminology.layout_description(layout) %>
        </option>
      <% end %>
    </select>
    <label class="label">
      <span class="label-text-alt text-base-content/60">
        Choose your preferred meal planning interface
      </span>
    </label>
  </div>
</.section>
```

## Testing Strategy

### Shared Infrastructure Tests

```elixir
describe "layout switching" do
  test "respects user preference", %{conn: conn, user: user} do
    user |> Ash.Changeset.for_update(:update, %{meal_planner_layout: :focus}) |> Ash.update!()

    {:ok, view, _html} = live(conn, ~p"/meal-planner")
    assert has_element?(view, "[data-layout='focus']")
  end

  test "URL param overrides preference", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/meal-planner?layout=power")
    assert has_element?(view, "[data-layout='power']")
  end

  test "persists layout change to database", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/meal-planner")

    view |> element("[phx-click='switch_layout'][phx-value-layout='power']") |> render_click()

    updated_user = Repo.get!(User, user.id)
    assert updated_user.meal_planner_layout == :power
  end
end

describe "undo system" do
  test "can undo meal creation", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/meal-planner")

    # Create a meal
    # ... click add ...

    # Undo
    view |> element("[phx-click='undo']") |> render_click()

    # Meal should be gone
    assert MealPlan |> Repo.all() |> length() == 0
  end
end
```

## Dependencies

- No new external dependencies
- Uses existing Ash/Phoenix infrastructure

## Implementation Order

1. **Database migration** - Add `meal_planner_layout` to users
2. **Terminology module** - Ensure consistency from start
3. **Layout dispatcher** - Core switching logic
4. **DataLoader module** - Shared data fetching
5. **UndoSystem** - Undo/redo with toast
6. **RecipePicker component** - Reusable picker
7. **Skeleton components** - Loading states
8. **Settings integration** - User preference UI
9. **Layout switcher dropdown** - In-app switching

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Layout switch success | 100% | No errors on switch |
| Preference persistence | 100% | Saves to DB correctly |
| Undo reliability | 100% | All undos work |
| Component reuse | 80%+ | Shared code across modes |

## References

- [UI Improvements Meal Planner](../docs/ui_improvements_meal_planner.md)
- [Meal Planner Layout Checklist](../docs/meal_planner_layout_checklist.md)
