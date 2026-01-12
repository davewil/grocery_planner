# MP-001: Meal Planner Explorer Mode

## Overview

**Feature:** Recipe-centric meal planning with discovery feed and timeline integration
**Priority:** High (Default Mode - Iteration 1)
**Target Persona:** Foodie Explorers
**Estimated Effort:** 8-12 days

## Problem Statement

Current meal planning interfaces focus on the calendar grid, requiring users to know exactly what they want to cook before planning. This approach doesn't serve users who:
- Browse for inspiration before planning
- Discover recipes first, then fit them into their schedule
- Want to explore based on what's in their fridge

**Current Pain Points:**
- Must know recipe name before adding to plan
- Recipe discovery and planning are separate experiences
- No quick path from "this looks good" to "it's on my plan"
- Mobile experience optimized for calendar, not discovery

## User Stories

### US-001: Browse recipes while seeing my week
**As a** Foodie Explorer
**I want** to browse recipes while seeing my meal plan
**So that** I can discover and plan in one flow

**Acceptance Criteria:**
- [x] Recipe discovery feed visible alongside week timeline
- [x] Timeline shows current week's planned meals
- [x] Can scroll through recipes without losing plan context
- [x] Works on both mobile and desktop

### US-002: Quick add from discovery feed
**As a** user finding an interesting recipe
**I want** to add it to my plan with minimal clicks
**So that** planning feels effortless

**Acceptance Criteria:**
- [x] "Add to Plan" button on each recipe card
- [x] Opens slot picker (day + meal type)
- [x] Slot picker shows availability at a glance
- [x] Success confirmation with undo option
- [ ] Animation feedback when recipe is added

### US-003: Filter recipes by time and availability
**As a** busy user
**I want** to filter recipes by cooking time and pantry availability
**So that** I find practical options quickly

**Acceptance Criteria:**
- [x] Quick filter chips: "Under 30 min", "Pantry-first"
- [x] Difficulty filter
- [x] Filters persist during session
- [x] Clear all filters option
- [ ] Show count of matching recipes

### US-004: See favorites and recently planned
**As a** returning user
**I want** quick access to favorites and recent recipes
**So that** I can reuse tried-and-true meals

**Acceptance Criteria:**
- [x] Favorites section at top of feed
- [x] Recently planned section (last 2 weeks)
- [x] Can collapse/expand these sections
- [x] Quick add from these sections

### US-005: Mobile-first timeline interaction
**As a** mobile user
**I want** a compact timeline that expands when needed
**So that** I have more space for recipe browsing

**Acceptance Criteria:**
- [x] Collapsible week strip on mobile
- [x] Day chips show planned count/indicators
- [x] Tap day to expand and see meal slots
- [x] Empty slots are tappable to add meal

## Technical Specification

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Explorer Mode Layout                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Search Bar (sticky on mobile)           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │         Week Timeline Strip (collapsible)            │   │
│  │  [Mon] [Tue] [Wed] [Thu] [Fri] [Sat] [Sun]          │   │
│  │    2     1     0     0     0     0     0   ← counts  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌──────────────────────┐ ┌────────────────────────────┐   │
│  │   Day Detail Panel   │ │    Recipe Discovery Feed    │   │
│  │   (expanded day)     │ │                            │   │
│  │                      │ │  [Filter Chips]            │   │
│  │  Breakfast: empty    │ │                            │   │
│  │  Lunch: Salad       │ │  ┌────────────────────┐    │   │
│  │  Dinner: empty      │ │  │  Recipe Card       │    │   │
│  │  Snack: empty       │ │  │  [Add to Plan]     │    │   │
│  │                      │ │  └────────────────────┘    │   │
│  │  [+ Add meal]        │ │                            │   │
│  └──────────────────────┘ │  ┌────────────────────┐    │   │
│         ↑                 │  │  Recipe Card       │    │   │
│    Desktop: Left pane     │  │  [Add to Plan]     │    │   │
│    Mobile: Bottom sheet   │  └────────────────────┘    │   │
│                           └────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Component Structure

```
MealPlannerLive (layout: :explorer)
├── WeekTimelineStrip
│   ├── DayChip (x7)
│   │   └── PlannedCountBadge
│   └── NavigationControls (prev/today/next)
├── DayDetailPanel
│   ├── MealSlot (x4: breakfast, lunch, dinner, snack)
│   │   ├── PlannedMealCard (if filled)
│   │   └── EmptySlotButton (if empty)
│   └── DayActions
├── RecipeDiscoveryFeed
│   ├── SearchInput
│   ├── FilterChips
│   ├── FavoritesSection (collapsible)
│   ├── RecentlyPlannedSection (collapsible)
│   └── RecipeGrid
│       └── RecipeCard (with AddToPlan CTA)
└── SlotPickerModal
    ├── DaySelector
    ├── MealTypeSelector
    └── ConfirmButton
```

### State Management

```elixir
defmodule GroceryPlannerWeb.MealPlannerLive do
  # Explorer mode specific assigns
  @explorer_assigns %{
    # Timeline state
    selected_date: Date.utc_today(),
    week_start: nil,  # Monday of current week
    week_meals: %{},  # %{date => [meals]}
    expanded_day: nil,  # Which day is expanded (mobile)

    # Discovery feed state
    recipes: [],
    favorites: [],
    recently_planned: [],
    search_query: "",
    filters: %{
      under_30_min: false,
      pantry_first: false,
      difficulty: nil
    },
    recipes_loading: false,

    # Slot picker state
    show_slot_picker: false,
    slot_picker_recipe: nil,
    selected_slot: nil  # %{date: Date, meal_type: atom}
  }
end
```

### Database Queries

**Fetch Week Meals:**
```elixir
def list_week_meals(account_id, week_start) do
  week_end = Date.add(week_start, 6)

  MealPlan
  |> where([mp], mp.account_id == ^account_id)
  |> where([mp], mp.scheduled_date >= ^week_start and mp.scheduled_date <= ^week_end)
  |> preload(:recipe)
  |> Repo.all()
  |> Enum.group_by(& &1.scheduled_date)
end
```

**Fetch Discovery Feed Recipes:**
```elixir
def list_discovery_recipes(account_id, filters) do
  Recipe
  |> where([r], r.account_id == ^account_id)
  |> maybe_filter_time(filters.under_30_min)
  |> maybe_filter_difficulty(filters.difficulty)
  |> maybe_filter_pantry_first(filters.pantry_first, account_id)
  |> order_by([r], [desc: r.is_favorite, desc: r.updated_at])
  |> limit(50)
  |> preload(:recipe_ingredients)
  |> Repo.all()
end

defp maybe_filter_time(query, true) do
  where(query, [r], r.prep_time_minutes + r.cook_time_minutes <= 30)
end
defp maybe_filter_time(query, _), do: query

defp maybe_filter_pantry_first(query, true, account_id) do
  # Sort by ingredient availability
  query
  |> order_by([r], desc: fragment("
    (SELECT COUNT(*) FROM recipe_ingredients ri
     JOIN inventory_entries ie ON ie.grocery_item_id = ri.grocery_item_id
     WHERE ri.recipe_id = ? AND ie.account_id = ? AND ie.status = 'available')
    ", r.id, ^account_id))
end
defp maybe_filter_pantry_first(query, _, _), do: query
```

**Recently Planned Recipes:**
```elixir
def list_recently_planned_recipes(account_id, days \\ 14) do
  since = Date.add(Date.utc_today(), -days)

  MealPlan
  |> where([mp], mp.account_id == ^account_id)
  |> where([mp], mp.scheduled_date >= ^since)
  |> distinct([mp], mp.recipe_id)
  |> order_by([mp], desc: mp.scheduled_date)
  |> limit(10)
  |> preload(:recipe)
  |> Repo.all()
  |> Enum.map(& &1.recipe)
end
```

### LiveView Events

```elixir
# Timeline navigation
def handle_event("prev_week", _, socket)
def handle_event("next_week", _, socket)
def handle_event("today", _, socket)
def handle_event("select_day", %{"date" => date}, socket)
def handle_event("expand_day", %{"date" => date}, socket)  # Mobile
def handle_event("collapse_day", _, socket)  # Mobile

# Discovery feed
def handle_event("search", %{"query" => query}, socket)
def handle_event("toggle_filter", %{"filter" => filter}, socket)
def handle_event("clear_filters", _, socket)
def handle_event("load_more_recipes", _, socket)

# Slot picker
def handle_event("open_slot_picker", %{"recipe-id" => id}, socket)
def handle_event("select_slot", %{"date" => d, "meal_type" => t}, socket)
def handle_event("confirm_add_to_plan", _, socket)
def handle_event("close_slot_picker", _, socket)

# Meal management
def handle_event("edit_meal", %{"id" => id}, socket)
def handle_event("remove_meal", %{"id" => id}, socket)
def handle_event("quick_add_to_slot", %{"recipe-id" => rid, "date" => d, "meal_type" => t}, socket)
```

## UI/UX Specifications

### Desktop Layout (≥1024px)

```heex
<div class="flex h-[calc(100vh-4rem)]">
  <!-- Left Pane: Timeline + Day Detail -->
  <div class="w-80 border-r border-base-300 flex flex-col">
    <!-- Week Navigation -->
    <div class="p-4 border-b border-base-300">
      <div class="flex items-center justify-between mb-3">
        <button class="btn btn-ghost btn-sm" phx-click="prev_week">
          <.icon name="hero-chevron-left" class="w-4 h-4" />
        </button>
        <span class="font-medium"><%= format_week_range(@week_start) %></span>
        <button class="btn btn-ghost btn-sm" phx-click="next_week">
          <.icon name="hero-chevron-right" class="w-4 h-4" />
        </button>
      </div>

      <!-- Day Chips -->
      <div class="flex gap-1">
        <%= for {date, day_name} <- week_days(@week_start) do %>
          <button
            class={[
              "flex-1 flex flex-col items-center p-2 rounded-lg transition-colors",
              if(date == @selected_date, do: "bg-primary text-primary-content", else: "hover:bg-base-200")
            ]}
            phx-click="select_day"
            phx-value-date={Date.to_iso8601(date)}
          >
            <span class="text-xs"><%= day_name %></span>
            <span class="text-sm font-medium"><%= date.day %></span>
            <%= if count = meal_count(@week_meals, date) do %>
              <span class="badge badge-xs mt-1"><%= count %></span>
            <% end %>
          </button>
        <% end %>
      </div>
    </div>

    <!-- Day Detail -->
    <div class="flex-1 overflow-y-auto p-4">
      <h3 class="font-medium mb-4"><%= format_date(@selected_date) %></h3>

      <div class="space-y-3">
        <%= for meal_type <- [:breakfast, :lunch, :dinner, :snack] do %>
          <div class="bg-base-200 rounded-lg p-3">
            <div class="text-xs text-base-content/70 uppercase mb-2">
              <%= meal_type %>
            </div>

            <%= if meal = get_meal(@week_meals, @selected_date, meal_type) do %>
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <%= if meal.recipe.image_url do %>
                    <img src={meal.recipe.image_url} class="w-10 h-10 rounded object-cover" />
                  <% end %>
                  <span class="font-medium text-sm"><%= meal.recipe.name %></span>
                </div>
                <div class="dropdown dropdown-end">
                  <button tabindex="0" class="btn btn-ghost btn-xs btn-square">
                    <.icon name="hero-ellipsis-vertical" class="w-4 h-4" />
                  </button>
                  <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box shadow-lg w-32 z-10">
                    <li><a phx-click="edit_meal" phx-value-id={meal.id}>Edit</a></li>
                    <li><a phx-click="remove_meal" phx-value-id={meal.id} class="text-error">Remove</a></li>
                  </ul>
                </div>
              </div>
            <% else %>
              <button
                class="w-full text-left text-sm text-base-content/50 hover:text-primary transition-colors"
                phx-click="open_slot_picker"
                phx-value-date={Date.to_iso8601(@selected_date)}
                phx-value-meal-type={meal_type}
              >
                + Add <%= meal_type %>
              </button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
  </div>

  <!-- Right Pane: Recipe Discovery -->
  <div class="flex-1 flex flex-col">
    <!-- Search & Filters -->
    <div class="p-4 border-b border-base-300 space-y-3">
      <div class="relative">
        <input
          type="text"
          placeholder="Search recipes..."
          value={@search_query}
          class="input input-bordered w-full pl-10"
          phx-change="search"
          phx-debounce="300"
          name="query"
        />
        <.icon name="hero-magnifying-glass" class="w-5 h-5 absolute left-3 top-1/2 -translate-y-1/2 text-base-content/50" />
      </div>

      <div class="flex flex-wrap gap-2">
        <button
          class={["btn btn-sm", if(@filters.under_30_min, do: "btn-primary", else: "btn-outline")]}
          phx-click="toggle_filter"
          phx-value-filter="under_30_min"
        >
          <.icon name="hero-clock" class="w-4 h-4" />
          Under 30 min
        </button>
        <button
          class={["btn btn-sm", if(@filters.pantry_first, do: "btn-primary", else: "btn-outline")]}
          phx-click="toggle_filter"
          phx-value-filter="pantry_first"
        >
          <.icon name="hero-archive-box" class="w-4 h-4" />
          Pantry-first
        </button>
        <select
          class="select select-bordered select-sm"
          phx-change="toggle_filter"
          name="difficulty"
        >
          <option value="">Any difficulty</option>
          <option value="easy" selected={@filters.difficulty == :easy}>Easy</option>
          <option value="medium" selected={@filters.difficulty == :medium}>Medium</option>
          <option value="hard" selected={@filters.difficulty == :hard}>Hard</option>
        </select>

        <%= if any_filters_active?(@filters) do %>
          <button class="btn btn-ghost btn-sm" phx-click="clear_filters">
            Clear all
          </button>
        <% end %>
      </div>
    </div>

    <!-- Recipe Feed -->
    <div class="flex-1 overflow-y-auto p-4">
      <!-- Favorites Section -->
      <%= if @favorites != [] do %>
        <.collapsible_section title="Favorites" icon="hero-heart" count={length(@favorites)}>
          <div class="grid grid-cols-2 xl:grid-cols-3 gap-3">
            <%= for recipe <- @favorites do %>
              <.explorer_recipe_card recipe={recipe} />
            <% end %>
          </div>
        </.collapsible_section>
      <% end %>

      <!-- Recently Planned Section -->
      <%= if @recently_planned != [] do %>
        <.collapsible_section title="Recently Planned" icon="hero-clock" count={length(@recently_planned)}>
          <div class="grid grid-cols-2 xl:grid-cols-3 gap-3">
            <%= for recipe <- @recently_planned do %>
              <.explorer_recipe_card recipe={recipe} />
            <% end %>
          </div>
        </.collapsible_section>
      <% end %>

      <!-- All Recipes -->
      <div class="mt-6">
        <h3 class="font-medium mb-3">All Recipes</h3>
        <%= if @recipes == [] do %>
          <.empty_state
            icon="hero-book-open"
            title="No recipes found"
            description="Try adjusting your filters or search terms"
          >
            <:action>
              <button class="btn btn-primary btn-sm" phx-click="clear_filters">
                Clear filters
              </button>
            </:action>
          </.empty_state>
        <% else %>
          <div class="grid grid-cols-2 xl:grid-cols-3 gap-3">
            <%= for recipe <- @recipes do %>
              <.explorer_recipe_card recipe={recipe} />
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
  </div>
</div>
```

### Mobile Layout (<1024px)

```heex
<div class="flex flex-col h-[calc(100vh-4rem)]">
  <!-- Sticky Header: Search -->
  <div class="sticky top-0 z-10 bg-base-100 p-3 border-b border-base-300">
    <input
      type="text"
      placeholder="Search recipes..."
      value={@search_query}
      class="input input-bordered input-sm w-full"
      phx-change="search"
      phx-debounce="300"
      name="query"
    />
  </div>

  <!-- Collapsible Week Strip -->
  <div class="bg-base-200 border-b border-base-300">
    <div class="flex items-center justify-between px-3 py-2">
      <button class="btn btn-ghost btn-xs" phx-click="prev_week">
        <.icon name="hero-chevron-left" class="w-4 h-4" />
      </button>

      <div class="flex gap-1 flex-1 justify-center">
        <%= for {date, day_name} <- week_days(@week_start) do %>
          <button
            class={[
              "flex flex-col items-center p-1.5 rounded-lg min-w-[40px]",
              cond do
                date == @expanded_day -> "bg-primary text-primary-content"
                date == @selected_date -> "bg-primary/20"
                true -> ""
              end
            ]}
            phx-click="expand_day"
            phx-value-date={Date.to_iso8601(date)}
          >
            <span class="text-[10px]"><%= String.slice(day_name, 0, 1) %></span>
            <span class="text-xs font-medium"><%= date.day %></span>
            <%= if has_meals?(@week_meals, date) do %>
              <span class="w-1.5 h-1.5 rounded-full bg-success mt-0.5"></span>
            <% else %>
              <span class="w-1.5 h-1.5 rounded-full bg-warning/50 mt-0.5"></span>
            <% end %>
          </button>
        <% end %>
      </div>

      <button class="btn btn-ghost btn-xs" phx-click="next_week">
        <.icon name="hero-chevron-right" class="w-4 h-4" />
      </button>
    </div>

    <!-- Expanded Day Detail (slides down) -->
    <%= if @expanded_day do %>
      <div class="px-3 pb-3 animate-slide-down">
        <div class="bg-base-100 rounded-lg p-3">
          <div class="flex items-center justify-between mb-2">
            <span class="font-medium text-sm"><%= format_date(@expanded_day) %></span>
            <button class="btn btn-ghost btn-xs" phx-click="collapse_day">
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>
          </div>

          <div class="flex gap-2 overflow-x-auto pb-1">
            <%= for meal_type <- [:breakfast, :lunch, :dinner, :snack] do %>
              <%= if meal = get_meal(@week_meals, @expanded_day, meal_type) do %>
                <div class="flex-shrink-0 bg-base-200 rounded-lg p-2 min-w-[100px]">
                  <div class="text-[10px] text-base-content/60 uppercase"><%= meal_type %></div>
                  <div class="text-xs font-medium truncate"><%= meal.recipe.name %></div>
                </div>
              <% else %>
                <button
                  class="flex-shrink-0 border border-dashed border-base-300 rounded-lg p-2 min-w-[80px] text-center"
                  phx-click="open_slot_picker"
                  phx-value-date={Date.to_iso8601(@expanded_day)}
                  phx-value-meal-type={meal_type}
                >
                  <div class="text-[10px] text-base-content/60 uppercase"><%= meal_type %></div>
                  <div class="text-xs text-base-content/50">+ Add</div>
                </button>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
  </div>

  <!-- Filter Chips (horizontal scroll) -->
  <div class="flex gap-2 px-3 py-2 overflow-x-auto border-b border-base-300">
    <button
      class={["btn btn-xs", if(@filters.under_30_min, do: "btn-primary", else: "btn-outline")]}
      phx-click="toggle_filter"
      phx-value-filter="under_30_min"
    >
      Under 30 min
    </button>
    <button
      class={["btn btn-xs", if(@filters.pantry_first, do: "btn-primary", else: "btn-outline")]}
      phx-click="toggle_filter"
      phx-value-filter="pantry_first"
    >
      Pantry-first
    </button>
    <!-- More filters in bottom sheet -->
    <button class="btn btn-xs btn-outline" phx-click="show_filter_sheet">
      <.icon name="hero-adjustments-horizontal" class="w-3 h-3" />
      More
    </button>
  </div>

  <!-- Recipe Feed (scrollable) -->
  <div class="flex-1 overflow-y-auto p-3">
    <div class="grid grid-cols-2 gap-3">
      <%= for recipe <- @recipes do %>
        <.explorer_recipe_card_mobile recipe={recipe} />
      <% end %>
    </div>
  </div>
</div>
```

### Recipe Card Component

```heex
<.live_component
  module={ExplorerRecipeCard}
  id={"recipe-#{recipe.id}"}
  recipe={recipe}
/>

# Component implementation
defmodule GroceryPlannerWeb.Components.ExplorerRecipeCard do
  use GroceryPlannerWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow group">
      <!-- Image -->
      <figure class="relative aspect-[4/3]">
        <%= if @recipe.image_url do %>
          <img src={@recipe.image_url} alt={@recipe.name} class="object-cover w-full h-full" />
        <% else %>
          <div class="w-full h-full bg-base-200 flex items-center justify-center">
            <.icon name="hero-photo" class="w-12 h-12 text-base-content/30" />
          </div>
        <% end %>

        <!-- Favorite badge -->
        <%= if @recipe.is_favorite do %>
          <div class="absolute top-2 left-2">
            <.icon name="hero-heart-solid" class="w-5 h-5 text-error" />
          </div>
        <% end %>

        <!-- Quick add overlay on hover -->
        <div class="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
          <button
            class="btn btn-primary btn-sm"
            phx-click="open_slot_picker"
            phx-value-recipe-id={@recipe.id}
          >
            <.icon name="hero-plus" class="w-4 h-4" />
            Add to Plan
          </button>
        </div>
      </figure>

      <div class="card-body p-3">
        <h3 class="card-title text-sm line-clamp-1"><%= @recipe.name %></h3>

        <div class="flex flex-wrap gap-1 mt-1">
          <!-- Time badge -->
          <span class="badge badge-ghost badge-xs">
            <.icon name="hero-clock" class="w-3 h-3 mr-1" />
            <%= @recipe.total_time_minutes %> min
          </span>

          <!-- Difficulty -->
          <span class={["badge badge-xs", difficulty_badge_class(@recipe.difficulty)]}>
            <%= @recipe.difficulty %>
          </span>

          <!-- Availability -->
          <%= if @recipe.can_make do %>
            <span class="badge badge-success badge-xs">Ready</span>
          <% else %>
            <span class="badge badge-warning badge-xs">
              <%= trunc(@recipe.ingredient_availability) %>%
            </span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
```

### Slot Picker Modal

```heex
<.modal :if={@show_slot_picker} id="slot-picker-modal" on_cancel={JS.push("close_slot_picker")}>
  <h3 class="font-bold text-lg mb-4">Add to Meal Plan</h3>

  <%= if @slot_picker_recipe do %>
    <div class="flex items-center gap-3 mb-4 p-3 bg-base-200 rounded-lg">
      <%= if @slot_picker_recipe.image_url do %>
        <img src={@slot_picker_recipe.image_url} class="w-16 h-16 rounded-lg object-cover" />
      <% end %>
      <div>
        <p class="font-medium"><%= @slot_picker_recipe.name %></p>
        <p class="text-sm text-base-content/70">
          <%= @slot_picker_recipe.total_time_minutes %> min • <%= @slot_picker_recipe.difficulty %>
        </p>
      </div>
    </div>
  <% end %>

  <!-- Day Selection -->
  <div class="mb-4">
    <label class="label"><span class="label-text font-medium">Select Day</span></label>
    <div class="grid grid-cols-7 gap-1">
      <%= for {date, day_name} <- week_days(@week_start) do %>
        <button
          class={[
            "flex flex-col items-center p-2 rounded-lg border transition-colors",
            if(@selected_slot && @selected_slot.date == date,
              do: "border-primary bg-primary/10",
              else: "border-base-300 hover:border-primary")
          ]}
          phx-click="select_slot"
          phx-value-date={Date.to_iso8601(date)}
          phx-value-meal_type={@selected_slot && @selected_slot.meal_type}
        >
          <span class="text-xs text-base-content/70"><%= day_name %></span>
          <span class="font-medium"><%= date.day %></span>
        </button>
      <% end %>
    </div>
  </div>

  <!-- Meal Type Selection -->
  <div class="mb-6">
    <label class="label"><span class="label-text font-medium">Select Meal</span></label>
    <div class="grid grid-cols-4 gap-2">
      <%= for meal_type <- [:breakfast, :lunch, :dinner, :snack] do %>
        <%
          is_selected = @selected_slot && @selected_slot.meal_type == meal_type
          is_occupied = @selected_slot && slot_occupied?(@week_meals, @selected_slot.date, meal_type)
        %>
        <button
          class={[
            "p-3 rounded-lg border text-center transition-colors",
            cond do
              is_occupied -> "border-base-300 bg-base-200 text-base-content/50 cursor-not-allowed"
              is_selected -> "border-primary bg-primary/10"
              true -> "border-base-300 hover:border-primary"
            end
          ]}
          phx-click={unless is_occupied, do: "select_slot"}
          phx-value-date={@selected_slot && Date.to_iso8601(@selected_slot.date)}
          phx-value-meal_type={meal_type}
          disabled={is_occupied}
        >
          <.icon name={meal_type_icon(meal_type)} class="w-5 h-5 mx-auto mb-1" />
          <span class="text-xs capitalize"><%= meal_type %></span>
          <%= if is_occupied do %>
            <span class="text-[10px] block text-base-content/50">Taken</span>
          <% end %>
        </button>
      <% end %>
    </div>
  </div>

  <!-- Actions -->
  <div class="flex justify-end gap-2">
    <button class="btn btn-ghost" phx-click="close_slot_picker">Cancel</button>
    <button
      class="btn btn-primary"
      phx-click="confirm_add_to_plan"
      disabled={!@selected_slot || !@selected_slot.date || !@selected_slot.meal_type}
    >
      <.icon name="hero-plus" class="w-4 h-4" />
      Add to Plan
    </button>
  </div>
</.modal>
```

### Animations & Micro-interactions

```css
/* In assets/css/app.css */

/* Slide down animation for expanded day */
@keyframes slide-down {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.animate-slide-down {
  animation: slide-down 0.2s ease-out;
}

/* Card fly animation (when adding to plan) */
@keyframes fly-to-plan {
  0% {
    transform: scale(1);
    opacity: 1;
  }
  50% {
    transform: scale(0.8) translateX(-50px);
    opacity: 0.5;
  }
  100% {
    transform: scale(0.5) translateX(-200px);
    opacity: 0;
  }
}

.animate-fly-to-plan {
  animation: fly-to-plan 0.4s ease-in forwards;
}

/* Success pulse on slot */
@keyframes success-pulse {
  0%, 100% {
    box-shadow: 0 0 0 0 theme('colors.success / 40%');
  }
  50% {
    box-shadow: 0 0 0 8px theme('colors.success / 0%');
  }
}

.animate-success-pulse {
  animation: success-pulse 0.6s ease-out;
}
```

## Testing Strategy

### Unit Tests

```elixir
defmodule GroceryPlannerWeb.MealPlannerLive.ExplorerTest do
  use GroceryPlannerWeb.ConnCase

  describe "explorer mode" do
    test "renders discovery feed with recipes", %{conn: conn} do
      recipe = create_recipe()
      {:ok, view, _html} = live(conn, ~p"/meal-planner")

      assert has_element?(view, "[data-recipe-id='#{recipe.id}']")
    end

    test "filters recipes by time", %{conn: conn} do
      quick = create_recipe(prep_time_minutes: 10, cook_time_minutes: 10)
      slow = create_recipe(prep_time_minutes: 30, cook_time_minutes: 60)

      {:ok, view, _html} = live(conn, ~p"/meal-planner")

      view |> element("[phx-value-filter='under_30_min']") |> render_click()

      assert has_element?(view, "[data-recipe-id='#{quick.id}']")
      refute has_element?(view, "[data-recipe-id='#{slow.id}']")
    end

    test "opens slot picker when adding recipe", %{conn: conn} do
      recipe = create_recipe()
      {:ok, view, _html} = live(conn, ~p"/meal-planner")

      view |> element("[phx-click='open_slot_picker'][phx-value-recipe-id='#{recipe.id}']") |> render_click()

      assert has_element?(view, "#slot-picker-modal")
    end

    test "creates meal plan entry on confirm", %{conn: conn} do
      recipe = create_recipe()
      {:ok, view, _html} = live(conn, ~p"/meal-planner")

      view |> element("[phx-click='open_slot_picker'][phx-value-recipe-id='#{recipe.id}']") |> render_click()
      view |> element("[phx-click='select_slot'][phx-value-meal_type='dinner']") |> render_click()
      view |> element("[phx-click='confirm_add_to_plan']") |> render_click()

      assert has_element?(view, ~s([data-testid="success-toast"]))
    end
  end
end
```

### Integration Tests

```elixir
test "full flow: browse → filter → add to plan → see in timeline", %{conn: conn} do
  recipe = create_recipe(prep_time_minutes: 20, cook_time_minutes: 10)

  {:ok, view, _html} = live(conn, ~p"/meal-planner")

  # Apply filter
  view |> element("[phx-value-filter='under_30_min']") |> render_click()
  assert has_element?(view, "[data-recipe-id='#{recipe.id}']")

  # Add to plan
  view |> element("[phx-click='open_slot_picker'][phx-value-recipe-id='#{recipe.id}']") |> render_click()
  view |> element("[phx-click='select_slot'][phx-value-date='#{Date.utc_today()}'][phx-value-meal_type='dinner']") |> render_click()
  view |> element("[phx-click='confirm_add_to_plan']") |> render_click()

  # Verify in timeline
  assert has_element?(view, "[data-meal-slot='dinner'] [data-recipe-id='#{recipe.id}']")
end
```

## Dependencies

- Existing UI components (`item_card`, `empty_state`, etc.)
- Existing recipe and meal planning domain logic
- No new external dependencies

## Configuration

```elixir
# User preference stored in database
# users.meal_planner_layout enum: :explorer | :focus | :power

# Default layout
config :grocery_planner, :meal_planner,
  default_layout: :explorer
```

## Rollout Plan

1. **Phase 1:** Core layout structure (desktop + mobile)
2. **Phase 2:** Recipe discovery feed with search
3. **Phase 3:** Filter functionality
4. **Phase 4:** Slot picker modal
5. **Phase 5:** Favorites and recently planned sections
6. **Phase 6:** Animations and polish
7. **Phase 7:** A/B test against current layout

## Success Metrics

| Metric | Target | Current | Measurement |
|--------|--------|---------|-------------|
| Add-to-plan conversion | > 30% | ~15% | Recipes viewed → added to plan |
| Time to first meal added | < 60s | ~3 min | New user onboarding |
| Discovery engagement | > 5 recipes viewed | ~2 | Scroll depth / views |
| Mobile usage | +25% | baseline | Mobile sessions on meal planner |

## References

- [UI Improvements Meal Planner](../docs/ui_improvements_meal_planner.md)
- [Meal Planner Layout Checklist](../docs/meal_planner_layout_checklist.md)
- [Component Library](../COMPONENT_LIBRARY.md)
