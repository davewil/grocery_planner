# MP-003: Meal Planner Power Mode

## Overview

**Feature:** Kanban-style week board with drag-and-drop meal planning
**Priority:** Low (Iteration 3)
**Target Persona:** Power Planners / Meal Prep Enthusiasts
**Estimated Effort:** 7-10 days

## Problem Statement

Advanced users who plan their entire week at once want a high-information-density view that lets them see and manipulate the whole week simultaneously. They value efficiency and batch operations over guided discovery.

**Target User Characteristics:**
- Plans entire week in one session
- Frequently moves meals between days
- Optimizes for ingredient overlap
- Values keyboard shortcuts and batch operations
- Primarily desktop users
- Comfortable with complex UIs

## User Stories

### US-001: See entire week at a glance
**As a** power planner
**I want** to see all meals for the week in one view
**So that** I can optimize my entire week efficiently

**Acceptance Criteria:**
- [ ] 7 columns visible (one per day)
- [ ] All meal types visible per day
- [ ] Recipe cards show key info (name, time, availability)
- [ ] Visual distinction for days with issues (missing ingredients)
- [ ] Compact view option for more density

### US-002: Drag and drop meals between days
**As a** user rearranging my week
**I want** to drag meals between days
**So that** I can quickly reorganize my plan

**Acceptance Criteria:**
- [ ] Drag recipe cards between day columns
- [ ] Drag within day to change meal type
- [ ] Visual drop zone indicators
- [ ] Undo support for moves
- [ ] Keyboard alternative (select + move)

### US-003: Batch operations on week
**As a** power user
**I want** bulk actions for the week
**So that** I can make sweeping changes quickly

**Acceptance Criteria:**
- [ ] "Clear week" button with confirmation
- [ ] "Copy last week" button
- [ ] "Auto-fill week" with optimization
- [ ] Select multiple meals for bulk delete
- [ ] Keyboard shortcuts for common actions

### US-004: Real-time grocery impact feedback
**As a** user optimizing my shopping
**I want** to see shopping impact as I move meals
**So that** I can minimize my grocery list

**Acceptance Criteria:**
- [ ] Running total of shopping items needed
- [ ] Delta feedback when moving meals (+2 items, -1 item)
- [ ] Highlight days with shopping needs
- [ ] "Optimize for shopping" suggestion

### US-005: Quick add from sidebar
**As a** user adding new meals
**I want** a recipe sidebar for quick adding
**So that** I can drag recipes directly onto the board

**Acceptance Criteria:**
- [ ] Collapsible recipe sidebar
- [ ] Search and filter recipes in sidebar
- [ ] Drag from sidebar to day column
- [ ] Recently used recipes at top
- [ ] Favorites pinned

## Technical Specification

### Architecture

```
┌───────────────────────────────────────────────────────────────────────────┐
│                          Power Mode Layout                                 │
├───────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │  Command Bar                                                         │ │
│  │  [◄ Prev] [Week of Jan 13-19, 2026] [Next ►]                        │ │
│  │  [Clear Week] [Copy Last Week] [Auto-fill] [⚡ Optimize]             │ │
│  │                                        🛒 Shopping: 12 items needed  │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│  ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┐ ┌─────────────────┐ │
│  │ Mon  │ Tue  │ Wed  │ Thu  │ Fri  │ Sat  │ Sun  │ │ Recipe Sidebar  │ │
│  │ 13   │ 14   │ 15   │ 16   │ 17   │ 18   │ 19   │ │                 │ │
│  ├──────┼──────┼──────┼──────┼──────┼──────┼──────┤ │ [Search...]     │ │
│  │      │      │      │      │      │      │      │ │                 │ │
│  │┌────┐│      │┌────┐│      │      │┌────┐│      │ │ ─ Favorites ─   │ │
│  ││Card││      ││Card││      │      ││Card││      │ │ [Recipe 1]      │ │
│  │└────┘│      │└────┘│      │      │└────┘│      │ │ [Recipe 2]      │ │
│  │      │┌────┐│      │┌────┐│┌────┐│      │┌────┐│ │                 │ │
│  │      ││Card││      ││Card│││Card││      ││Card││ │ ─ Recent ─      │ │
│  │      │└────┘│      │└────┘│└────┘│      │└────┘│ │ [Recipe 3]      │ │
│  │      │      │      │      │      │      │      │ │ [Recipe 4]      │ │
│  │ [+]  │ [+]  │ [+]  │ [+]  │ [+]  │ [+]  │ [+]  │ │                 │ │
│  └──────┴──────┴──────┴──────┴──────┴──────┴──────┘ │ ─ All ─         │ │
│                                                      │ [Recipe 5]      │ │
│  Drop zones highlighted during drag                  │ [Recipe 6]      │ │
│  Grocery delta shown on hover                        └─────────────────┘ │
└───────────────────────────────────────────────────────────────────────────┘
```

### Component Structure

```
MealPlannerLive (layout: :power)
├── CommandBar
│   ├── WeekNavigation
│   ├── BulkActions
│   └── ShoppingSummary
├── KanbanBoard
│   ├── DayColumn (x7)
│   │   ├── DayHeader
│   │   ├── MealTypeSection (x4)
│   │   │   └── MealCard (draggable)
│   │   └── DropZone
│   └── DragOverlay (floating card during drag)
├── RecipeSidebar (collapsible)
│   ├── SidebarSearch
│   ├── FavoritesSection
│   ├── RecentSection
│   └── AllRecipesSection
└── GroceryDeltaToast (shows +/- items on move)
```

### State Management

```elixir
defmodule GroceryPlannerWeb.MealPlannerLive do
  # Power mode specific assigns
  @power_assigns %{
    # Week data
    week_start: nil,
    week_meals: %{},  # %{date => %{meal_type => meal}}

    # Drag state
    dragging: nil,  # %{meal_id: id, source: {date, meal_type}}
    drag_over: nil,  # %{date: date, meal_type: type}
    drop_preview: nil,

    # Selection (for bulk operations)
    selected_meals: MapSet.new(),
    selection_mode: false,

    # Sidebar
    sidebar_open: true,
    sidebar_search: "",
    sidebar_recipes: [],

    # Grocery tracking
    week_shopping_items: [],
    grocery_delta: nil,  # Shown during drag: %{added: [], removed: []}

    # Undo stack
    undo_stack: [],
    redo_stack: []
  }
end
```

### Drag and Drop Implementation

Using a custom LiveView hook with the HTML5 Drag API:

```javascript
// assets/js/hooks/kanban_board.js
export const KanbanBoard = {
  mounted() {
    this.setupDragAndDrop();
    this.setupKeyboardShortcuts();
  },

  setupDragAndDrop() {
    // Make meal cards draggable
    this.el.querySelectorAll('[data-draggable="meal"]').forEach(card => {
      card.setAttribute('draggable', 'true');

      card.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('text/plain', card.dataset.mealId);
        e.dataTransfer.effectAllowed = 'move';
        card.classList.add('opacity-50');

        this.pushEvent("drag_start", {
          meal_id: card.dataset.mealId,
          source_date: card.dataset.date,
          source_type: card.dataset.mealType
        });
      });

      card.addEventListener('dragend', (e) => {
        card.classList.remove('opacity-50');
        this.pushEvent("drag_end", {});
      });
    });

    // Make drop zones accept drops
    this.el.querySelectorAll('[data-drop-zone]').forEach(zone => {
      zone.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        zone.classList.add('ring-2', 'ring-primary');

        this.pushEvent("drag_over", {
          date: zone.dataset.date,
          meal_type: zone.dataset.mealType
        });
      });

      zone.addEventListener('dragleave', (e) => {
        zone.classList.remove('ring-2', 'ring-primary');
      });

      zone.addEventListener('drop', (e) => {
        e.preventDefault();
        zone.classList.remove('ring-2', 'ring-primary');

        const mealId = e.dataTransfer.getData('text/plain');
        this.pushEvent("drop_meal", {
          meal_id: mealId,
          target_date: zone.dataset.date,
          target_type: zone.dataset.mealType
        });
      });
    });

    // Recipe sidebar drag
    this.el.querySelectorAll('[data-draggable="recipe"]').forEach(card => {
      card.setAttribute('draggable', 'true');

      card.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('application/recipe', card.dataset.recipeId);
        e.dataTransfer.effectAllowed = 'copy';
      });
    });
  },

  setupKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
      // Ctrl/Cmd + Z = Undo
      if ((e.ctrlKey || e.metaKey) && e.key === 'z' && !e.shiftKey) {
        e.preventDefault();
        this.pushEvent("undo", {});
      }

      // Ctrl/Cmd + Shift + Z = Redo
      if ((e.ctrlKey || e.metaKey) && e.key === 'z' && e.shiftKey) {
        e.preventDefault();
        this.pushEvent("redo", {});
      }

      // Delete = Remove selected meals
      if (e.key === 'Delete' || e.key === 'Backspace') {
        if (document.activeElement.tagName !== 'INPUT') {
          e.preventDefault();
          this.pushEvent("delete_selected", {});
        }
      }
    });
  }
};
```

### LiveView Events

```elixir
# Drag and drop
def handle_event("drag_start", %{"meal_id" => id, ...}, socket)
def handle_event("drag_over", %{"date" => d, "meal_type" => t}, socket)
def handle_event("drag_end", _, socket)
def handle_event("drop_meal", %{"meal_id" => id, "target_date" => d, "target_type" => t}, socket)
def handle_event("drop_recipe", %{"recipe_id" => id, "target_date" => d, "target_type" => t}, socket)

# Bulk operations
def handle_event("clear_week", _, socket)
def handle_event("copy_last_week", _, socket)
def handle_event("auto_fill_week", _, socket)
def handle_event("optimize_for_shopping", _, socket)

# Selection
def handle_event("toggle_selection", %{"meal_id" => id}, socket)
def handle_event("select_all", _, socket)
def handle_event("clear_selection", _, socket)
def handle_event("delete_selected", _, socket)

# Undo/Redo
def handle_event("undo", _, socket)
def handle_event("redo", _, socket)

# Sidebar
def handle_event("toggle_sidebar", _, socket)
def handle_event("search_sidebar", %{"query" => q}, socket)
```

## UI/UX Specifications

### Desktop Layout (Primary)

```heex
<div class="flex flex-col h-[calc(100vh-4rem)]" phx-hook="KanbanBoard" id="kanban-board">
  <!-- Command Bar -->
  <div class="bg-base-200 border-b border-base-300 px-4 py-3">
    <div class="flex items-center justify-between">
      <!-- Week Navigation -->
      <div class="flex items-center gap-2">
        <button class="btn btn-ghost btn-sm" phx-click="prev_week">
          <.icon name="hero-chevron-left" class="w-5 h-5" />
        </button>
        <span class="font-semibold text-lg min-w-[200px] text-center">
          <%= format_week_range(@week_start) %>
        </span>
        <button class="btn btn-ghost btn-sm" phx-click="next_week">
          <.icon name="hero-chevron-right" class="w-5 h-5" />
        </button>
        <button class="btn btn-ghost btn-sm" phx-click="today">Today</button>
      </div>

      <!-- Bulk Actions -->
      <div class="flex items-center gap-2">
        <button class="btn btn-outline btn-sm" phx-click="copy_last_week">
          <.icon name="hero-document-duplicate" class="w-4 h-4" />
          Copy Last Week
        </button>
        <button class="btn btn-outline btn-sm" phx-click="auto_fill_week">
          <.icon name="hero-sparkles" class="w-4 h-4" />
          Auto-fill
        </button>
        <button
          class="btn btn-outline btn-sm text-error"
          phx-click="clear_week"
          data-confirm="Are you sure you want to clear all meals this week?"
        >
          <.icon name="hero-trash" class="w-4 h-4" />
          Clear Week
        </button>
        <div class="divider divider-horizontal"></div>
        <button
          class="btn btn-sm"
          phx-click="toggle_sidebar"
        >
          <.icon name={if @sidebar_open, do: "hero-x-mark", else: "hero-bars-3"} class="w-4 h-4" />
        </button>
      </div>
    </div>

    <!-- Shopping Summary -->
    <div class="flex items-center justify-between mt-2 text-sm">
      <div class="flex items-center gap-4">
        <%= if @selected_meals != MapSet.new() do %>
          <span class="badge badge-primary">
            <%= MapSet.size(@selected_meals) %> selected
          </span>
          <button class="link link-primary text-xs" phx-click="delete_selected">
            Delete selected
          </button>
          <button class="link text-xs" phx-click="clear_selection">
            Clear selection
          </button>
        <% end %>
      </div>

      <div class="flex items-center gap-2">
        <.icon name="hero-shopping-cart" class="w-4 h-4" />
        <%= if length(@week_shopping_items) > 0 do %>
          <span><%= length(@week_shopping_items) %> items needed for this week</span>
          <button class="btn btn-primary btn-xs" phx-click="generate_shopping_list">
            Generate List
          </button>
        <% else %>
          <span class="text-success">All ingredients available!</span>
        <% end %>
      </div>
    </div>
  </div>

  <!-- Main Content -->
  <div class="flex flex-1 overflow-hidden">
    <!-- Kanban Board -->
    <div class="flex-1 overflow-x-auto">
      <div class="flex h-full min-w-[900px]">
        <%= for {date, day_name} <- week_days(@week_start) do %>
          <.day_column
            date={date}
            day_name={day_name}
            meals={@week_meals[date] || %{}}
            drag_over={@drag_over}
            selected={@selected_meals}
          />
        <% end %>
      </div>
    </div>

    <!-- Recipe Sidebar -->
    <div class={[
      "border-l border-base-300 bg-base-100 transition-all duration-300 overflow-hidden",
      if(@sidebar_open, do: "w-72", else: "w-0")
    ]}>
      <div class="w-72 h-full flex flex-col">
        <div class="p-3 border-b border-base-300">
          <input
            type="text"
            placeholder="Search recipes..."
            class="input input-bordered input-sm w-full"
            value={@sidebar_search}
            phx-change="search_sidebar"
            phx-debounce="200"
            name="query"
          />
        </div>

        <div class="flex-1 overflow-y-auto p-3">
          <!-- Favorites -->
          <%= if @favorite_recipes != [] do %>
            <div class="mb-4">
              <h4 class="text-xs font-bold uppercase text-base-content/60 mb-2">
                <.icon name="hero-heart" class="w-3 h-3 inline" /> Favorites
              </h4>
              <div class="space-y-1">
                <%= for recipe <- @favorite_recipes do %>
                  <.sidebar_recipe_card recipe={recipe} />
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- Recent -->
          <%= if @recent_recipes != [] do %>
            <div class="mb-4">
              <h4 class="text-xs font-bold uppercase text-base-content/60 mb-2">
                <.icon name="hero-clock" class="w-3 h-3 inline" /> Recent
              </h4>
              <div class="space-y-1">
                <%= for recipe <- @recent_recipes do %>
                  <.sidebar_recipe_card recipe={recipe} />
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- All Recipes -->
          <div>
            <h4 class="text-xs font-bold uppercase text-base-content/60 mb-2">
              All Recipes
            </h4>
            <div class="space-y-1">
              <%= for recipe <- @sidebar_recipes do %>
                <.sidebar_recipe_card recipe={recipe} />
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Grocery Delta Toast (shown during drag) -->
  <%= if @grocery_delta do %>
    <div class="fixed bottom-4 left-1/2 -translate-x-1/2 z-50">
      <div class="bg-base-100 rounded-lg shadow-xl px-4 py-2 flex items-center gap-4">
        <%= if @grocery_delta.added != [] do %>
          <span class="text-warning">
            +<%= length(@grocery_delta.added) %> items
          </span>
        <% end %>
        <%= if @grocery_delta.removed != [] do %>
          <span class="text-success">
            -<%= length(@grocery_delta.removed) %> items
          </span>
        <% end %>
      </div>
    </div>
  <% end %>

  <!-- Undo Toast -->
  <%= if @show_undo_toast do %>
    <div class="toast toast-end">
      <div class="alert shadow-lg">
        <span><%= @undo_message %></span>
        <button class="btn btn-sm btn-ghost" phx-click="undo">Undo</button>
      </div>
    </div>
  <% end %>
</div>
```

### Day Column Component

```heex
<div class={[
  "flex-1 min-w-[120px] border-r border-base-300 last:border-r-0 flex flex-col",
  if(@date == Date.utc_today(), do: "bg-primary/5")
]}>
  <!-- Day Header -->
  <div class={[
    "p-2 text-center border-b border-base-300 sticky top-0 z-10",
    if(@date == Date.utc_today(), do: "bg-primary/10", else: "bg-base-200")
  ]}>
    <div class="text-xs text-base-content/60"><%= @day_name %></div>
    <div class="text-lg font-bold"><%= @date.day %></div>
    <%= if shopping_needed?(@meals) do %>
      <.icon name="hero-shopping-cart" class="w-3 h-3 text-warning" />
    <% end %>
  </div>

  <!-- Meal Slots -->
  <div class="flex-1 overflow-y-auto p-1 space-y-1">
    <%= for meal_type <- [:breakfast, :lunch, :dinner, :snack] do %>
      <div
        class={[
          "rounded-lg p-1 min-h-[60px] transition-colors",
          drop_zone_class(@drag_over, @date, meal_type)
        ]}
        data-drop-zone
        data-date={Date.to_iso8601(@date)}
        data-meal-type={meal_type}
      >
        <div class="text-[10px] uppercase text-base-content/50 mb-1 px-1">
          <%= meal_type %>
        </div>

        <%= if meal = @meals[meal_type] do %>
          <.kanban_meal_card
            meal={meal}
            selected={MapSet.member?(@selected, meal.id)}
          />
        <% else %>
          <button
            class="w-full h-10 border border-dashed border-base-300 rounded text-base-content/30 hover:border-primary hover:text-primary text-xs"
            phx-click="quick_add"
            phx-value-date={Date.to_iso8601(@date)}
            phx-value-meal-type={meal_type}
          >
            +
          </button>
        <% end %>
      </div>
    <% end %>
  </div>
</div>
```

### Kanban Meal Card

```heex
<div
  class={[
    "bg-base-100 rounded-lg p-2 shadow-sm cursor-grab active:cursor-grabbing group",
    if(@selected, do: "ring-2 ring-primary")
  ]}
  data-draggable="meal"
  data-meal-id={@meal.id}
  data-date={Date.to_iso8601(@meal.scheduled_date)}
  data-meal-type={@meal.meal_type}
>
  <div class="flex items-start justify-between gap-1">
    <div class="flex-1 min-w-0">
      <p class="text-xs font-medium truncate"><%= @meal.recipe.name %></p>
      <p class="text-[10px] text-base-content/50">
        <%= @meal.recipe.total_time_minutes %> min
      </p>
    </div>

    <!-- Selection checkbox (visible on hover) -->
    <input
      type="checkbox"
      class="checkbox checkbox-xs opacity-0 group-hover:opacity-100"
      checked={@selected}
      phx-click="toggle_selection"
      phx-value-meal-id={@meal.id}
    />
  </div>

  <!-- Availability indicator -->
  <%= if @meal.recipe.can_make do %>
    <div class="mt-1">
      <span class="badge badge-success badge-xs">Ready</span>
    </div>
  <% else %>
    <div class="mt-1">
      <span class="badge badge-warning badge-xs">
        <%= 100 - trunc(@meal.recipe.ingredient_availability) %>% missing
      </span>
    </div>
  <% end %>
</div>
```

### Sidebar Recipe Card (Draggable)

```heex
<div
  class="bg-base-200 rounded-lg p-2 cursor-grab active:cursor-grabbing hover:bg-base-300 transition-colors"
  data-draggable="recipe"
  data-recipe-id={@recipe.id}
>
  <div class="flex items-center gap-2">
    <%= if @recipe.image_url do %>
      <img src={@recipe.image_url} class="w-8 h-8 rounded object-cover" />
    <% else %>
      <div class="w-8 h-8 rounded bg-base-300 flex items-center justify-center">
        <.icon name="hero-photo" class="w-4 h-4 text-base-content/30" />
      </div>
    <% end %>
    <div class="flex-1 min-w-0">
      <p class="text-sm font-medium truncate"><%= @recipe.name %></p>
      <p class="text-xs text-base-content/50"><%= @recipe.total_time_minutes %> min</p>
    </div>
  </div>
</div>
```

### Mobile Layout (Simplified)

For mobile, Power Mode falls back to a simplified single-day view with reorder capability:

```heex
<div class="flex flex-col h-[calc(100vh-4rem)]">
  <!-- Day Pager -->
  <div class="bg-base-200 p-3 border-b border-base-300">
    <div class="flex items-center justify-between">
      <button class="btn btn-ghost btn-sm" phx-click="prev_day">
        <.icon name="hero-chevron-left" class="w-5 h-5" />
      </button>
      <div class="text-center">
        <div class="font-bold"><%= format_date(@selected_date) %></div>
        <div class="text-xs text-base-content/70">
          Swipe to navigate • Long-press to reorder
        </div>
      </div>
      <button class="btn btn-ghost btn-sm" phx-click="next_day">
        <.icon name="hero-chevron-right" class="w-5 h-5" />
      </button>
    </div>
  </div>

  <!-- Reorderable meal list -->
  <div class="flex-1 overflow-y-auto p-4" phx-hook="SortableMeals" id="sortable-meals">
    <%= for meal_type <- [:breakfast, :lunch, :dinner, :snack] do %>
      <div class="mb-4" data-meal-type={meal_type}>
        <h3 class="text-xs font-semibold uppercase text-base-content/60 mb-2">
          <%= meal_type %>
        </h3>
        <%= if meal = get_meal(@day_meals, meal_type) do %>
          <.mobile_power_card meal={meal} />
        <% else %>
          <button
            class="w-full p-4 rounded-xl border-2 border-dashed border-base-300 text-center"
            phx-click="add_meal"
            phx-value-slot={meal_type}
          >
            <span class="text-base-content/50">+ Add</span>
          </button>
        <% end %>
      </div>
    <% end %>
  </div>

  <!-- Week overview strip -->
  <div class="bg-base-200 p-2 border-t border-base-300">
    <div class="flex gap-1 justify-center">
      <%= for {date, _} <- week_days(@week_start) do %>
        <button
          class={[
            "w-8 h-8 rounded-lg flex flex-col items-center justify-center text-xs",
            if(date == @selected_date, do: "bg-primary text-primary-content", else: "")
          ]}
          phx-click="select_day"
          phx-value-date={Date.to_iso8601(date)}
        >
          <span><%= date.day %></span>
          <div class="flex gap-0.5 mt-0.5">
            <%= for _ <- 1..meal_count(@week_meals, date) do %>
              <span class="w-1 h-1 rounded-full bg-current"></span>
            <% end %>
          </div>
        </button>
      <% end %>
    </div>
  </div>
</div>
```

## Undo/Redo Implementation

```elixir
defmodule GroceryPlannerWeb.MealPlannerLive.UndoStack do
  @max_stack_size 20

  def push(stack, action) do
    [action | stack] |> Enum.take(@max_stack_size)
  end

  def pop([action | rest]), do: {action, rest}
  def pop([]), do: {nil, []}
end

# In LiveView
def handle_event("drop_meal", params, socket) do
  old_state = capture_meal_state(socket, params.meal_id)

  case move_meal(params) do
    {:ok, _} ->
      undo_action = {:move_meal, %{
        meal_id: params.meal_id,
        from: old_state,
        to: %{date: params.target_date, type: params.target_type}
      }}

      {:noreply,
        socket
        |> update(:undo_stack, &UndoStack.push(&1, undo_action))
        |> assign(:redo_stack, [])
        |> assign(:show_undo_toast, true)
        |> assign(:undo_message, "Meal moved")}

    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Failed to move meal")}
  end
end

def handle_event("undo", _, socket) do
  case UndoStack.pop(socket.assigns.undo_stack) do
    {nil, _} ->
      {:noreply, socket}

    {action, rest} ->
      apply_undo(socket, action)
      |> assign(:undo_stack, rest)
      |> update(:redo_stack, &UndoStack.push(&1, action))
  end
end
```

## Testing Strategy

### Unit Tests

```elixir
describe "power mode" do
  test "renders week board with all days", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/meal-planner?layout=power")

    for day <- 1..7 do
      assert has_element?(view, "[data-day-column]", "#{day}")
    end
  end

  test "moves meal between days via drop event", %{conn: conn} do
    meal = create_meal_plan(scheduled_date: ~D[2026-01-13], meal_type: :dinner)
    {:ok, view, _html} = live(conn, ~p"/meal-planner?layout=power")

    view |> render_hook("drop_meal", %{
      meal_id: meal.id,
      target_date: "2026-01-14",
      target_type: "lunch"
    })

    updated = Repo.get!(MealPlan, meal.id)
    assert updated.scheduled_date == ~D[2026-01-14]
    assert updated.meal_type == :lunch
  end

  test "supports undo after move", %{conn: conn} do
    meal = create_meal_plan(scheduled_date: ~D[2026-01-13])
    {:ok, view, _html} = live(conn, ~p"/meal-planner?layout=power")

    # Move meal
    view |> render_hook("drop_meal", %{...})

    # Undo
    view |> element("[phx-click='undo']") |> render_click()

    updated = Repo.get!(MealPlan, meal.id)
    assert updated.scheduled_date == ~D[2026-01-13]
  end
end
```

## Dependencies

- HTML5 Drag and Drop API
- JavaScript hooks for drag state management
- No new external dependencies

## Configuration

```elixir
# Power mode specific settings
config :grocery_planner, :meal_planner,
  power_mode: [
    max_undo_stack: 20,
    auto_save_delay_ms: 500,
    show_grocery_delta: true
  ]
```

## Rollout Plan

1. **Phase 1:** Basic Kanban board layout
2. **Phase 2:** Drag and drop between days
3. **Phase 3:** Recipe sidebar with drag-to-add
4. **Phase 4:** Selection and bulk operations
5. **Phase 5:** Undo/redo system
6. **Phase 6:** Grocery delta feedback
7. **Phase 7:** Mobile simplified view

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Meals moved per session | > 5 | Drag operations |
| Week planning completion | > 80% | 7+ meals planned |
| Undo usage | > 30% sessions | Users who use undo |
| Time to plan full week | < 5 min | Session duration |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl/Cmd + Z` | Undo |
| `Ctrl/Cmd + Shift + Z` | Redo |
| `Delete` / `Backspace` | Delete selected |
| `Escape` | Clear selection |
| `Ctrl/Cmd + A` | Select all visible |
| `←` / `→` | Navigate weeks |

## References

- [UI Improvements Meal Planner](../docs/ui_improvements_meal_planner.md)
- [Meal Planner Layout Checklist](../docs/meal_planner_layout_checklist.md)
- [HTML5 Drag and Drop API](https://developer.mozilla.org/en-US/docs/Web/API/HTML_Drag_and_Drop_API)
