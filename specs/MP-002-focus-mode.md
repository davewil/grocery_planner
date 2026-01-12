# MP-002: Meal Planner Focus Mode

## Overview

**Feature:** Today-first dashboard with minimal, fast day-by-day planning
**Priority:** Medium (Iteration 2)
**Target Persona:** Routine Planners / Busy Parents
**Estimated Effort:** 5-7 days

## Problem Statement

Some users don't need discovery—they know their recipes and just want to quickly plan their day or week with minimal friction. The Explorer mode's visual richness can feel overwhelming for these users.

**Target User Characteristics:**
- Has established recipe repertoire
- Plans day-by-day, not week-at-a-glance
- Values speed over discovery
- Often uses repeat meals (meal prep, leftovers)
- Mobile-first usage pattern

## User Stories

### US-001: See today's plan at a glance
**As a** busy user
**I want** to see today's meals immediately on load
**So that** I know what's planned without navigation

**Acceptance Criteria:**
- [x] Today's meals displayed prominently on page load
- [x] Current day highlighted in week strip
- [x] Show meal status (planned, in progress, completed)
- [x] Quick access to recipe details

### US-002: Quick day navigation
**As a** user planning multiple days
**I want** to swipe between days easily
**So that** I can plan the week day-by-day

**Acceptance Criteria:**
- [x] Swipeable week strip on mobile
- [x] Click to select day on desktop
- [x] Smooth transition between days
- [x] Visual indicator of which days have plans

### US-003: Fast meal slot actions
**As a** user filling meal slots
**I want** quick actions on each slot
**So that** planning is fast and fluid

**Acceptance Criteria:**
- [x] Tap empty slot to add meal
- [x] Swipe meal to remove/swap
- [x] Long-press for more options
- [x] Inline notes editing

### US-004: Repeat and copy shortcuts
**As a** user with recurring meals
**I want** shortcuts to repeat previous meals
**So that** I don't re-enter the same data

**Acceptance Criteria:**
- [x] "Repeat last week" button
- [x] "Copy yesterday's lunch" option
- [x] Recently used recipes in quick picker
- [x] Meal prep mode (same meal multiple days)

### US-005: Grocery impact visibility
**As a** user planning meals
**I want** to see shopping impact as I plan
**So that** I can balance convenience with what I have

**Acceptance Criteria:**
- [x] Show ingredient availability per meal
- [x] Running tally of shopping items needed
- [x] Highlight meals that need shopping
- [x] Quick link to generate shopping list

## Technical Specification

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Focus Mode Layout                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Week Strip (swipeable)                  │   │
│  │  ◄ [M] [T] [W] [T] [F] [S] [S] ►                    │   │
│  │      ●   ●   ○   ○   ○   ○   ○   ← plan indicators  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Selected Day Header                     │   │
│  │  Wednesday, January 15                               │   │
│  │  "3 meals planned, 1 needs shopping"                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  BREAKFAST                                           │   │
│  │  ┌─────────────────────────────────────────────┐    │   │
│  │  │  Overnight Oats           ✓ Ready            │    │   │
│  │  │  4 servings • 5 min prep                     │    │   │
│  │  │  [Swap] [Clear] [Notes]                      │    │   │
│  │  └─────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  LUNCH                                              │   │
│  │  ┌─────────────────────────────────────────────┐    │   │
│  │  │  + Add lunch                                 │    │   │
│  │  └─────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  DINNER                                             │   │
│  │  ┌─────────────────────────────────────────────┐    │   │
│  │  │  Chicken Stir Fry          ⚠️ 2 items needed │    │   │
│  │  │  4 servings • 35 min                         │    │   │
│  │  │  [Swap] [Clear] [Notes]                      │    │   │
│  │  └─────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  [+] Add Meal  |  🛒 Shopping: 2 items needed       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Desktop Only: Right sidebar with grocery summary          │
└─────────────────────────────────────────────────────────────┘
```

### Component Structure

```
MealPlannerLive (layout: :focus)
├── WeekStripSwipeable
│   └── DayPill (x7) with plan indicators
├── DayHeader
│   ├── DateDisplay
│   └── DaySummary (meals count, shopping needed)
├── MealSlotStack
│   └── MealSlotCard (x4)
│       ├── FilledSlot
│       │   ├── RecipeInfo
│       │   ├── AvailabilityBadge
│       │   └── QuickActions (Swap, Clear, Notes)
│       └── EmptySlot
│           └── AddMealButton
├── DayActions
│   ├── AddMealFAB (mobile)
│   └── ShoppingSummary
└── QuickRecipePicker (bottom sheet)
    ├── RecentRecipes
    ├── FavoriteRecipes
    └── SearchInput
```

### State Management

```elixir
defmodule GroceryPlannerWeb.MealPlannerLive do
  # Focus mode specific assigns
  @focus_assigns %{
    # Day navigation
    selected_date: Date.utc_today(),
    week_start: nil,
    week_plan_indicators: %{},  # %{date => :empty | :partial | :full}

    # Day meals
    day_meals: [],  # Meals for selected_date
    day_shopping_items: [],  # Missing ingredients for day

    # Quick picker
    show_quick_picker: false,
    quick_picker_slot: nil,  # :breakfast | :lunch | :dinner | :snack
    recent_recipes: [],
    favorite_recipes: [],

    # Swipe state (mobile)
    swipe_direction: nil,
    swipe_offset: 0
  }
end
```

### LiveView Events

```elixir
# Day navigation
def handle_event("select_day", %{"date" => date}, socket)
def handle_event("swipe_day", %{"direction" => dir}, socket)  # Mobile
def handle_event("today", _, socket)

# Meal slot actions
def handle_event("add_meal", %{"slot" => slot}, socket)
def handle_event("swap_meal", %{"id" => id}, socket)
def handle_event("clear_meal", %{"id" => id}, socket)
def handle_event("update_notes", %{"id" => id, "notes" => notes}, socket)
def handle_event("mark_complete", %{"id" => id}, socket)

# Quick picker
def handle_event("open_quick_picker", %{"slot" => slot}, socket)
def handle_event("close_quick_picker", _, socket)
def handle_event("select_recipe", %{"id" => id}, socket)
def handle_event("search_recipes", %{"query" => q}, socket)

# Shortcuts
def handle_event("repeat_last_week", _, socket)
def handle_event("copy_from", %{"date" => date, "slot" => slot}, socket)
def handle_event("auto_fill_day", _, socket)
```

## UI/UX Specifications

### Mobile Layout (Primary)

```heex
<div class="flex flex-col h-[calc(100vh-4rem)] bg-base-100">
  <!-- Swipeable Week Strip -->
  <div
    class="bg-base-200 py-3 touch-pan-x"
    phx-hook="SwipeableWeek"
    id="week-strip"
  >
    <div class="flex items-center justify-between px-2">
      <button class="btn btn-ghost btn-sm btn-square" phx-click="prev_week">
        <.icon name="hero-chevron-left" class="w-5 h-5" />
      </button>

      <div class="flex gap-1">
        <%= for {date, day_name} <- week_days(@week_start) do %>
          <button
            class={[
              "flex flex-col items-center py-2 px-3 rounded-xl transition-all",
              cond do
                date == @selected_date -> "bg-primary text-primary-content scale-105"
                date == Date.utc_today() -> "bg-primary/20"
                true -> "hover:bg-base-300"
              end
            ]}
            phx-click="select_day"
            phx-value-date={Date.to_iso8601(date)}
          >
            <span class="text-xs opacity-70"><%= String.slice(day_name, 0, 3) %></span>
            <span class="text-lg font-bold"><%= date.day %></span>
            <span class={[
              "w-2 h-2 rounded-full mt-1",
              plan_indicator_color(@week_plan_indicators[date])
            ]}></span>
          </button>
        <% end %>
      </div>

      <button class="btn btn-ghost btn-sm btn-square" phx-click="next_week">
        <.icon name="hero-chevron-right" class="w-5 h-5" />
      </button>
    </div>
  </div>

  <!-- Day Header -->
  <div class="px-4 py-3 border-b border-base-300">
    <h2 class="text-xl font-bold"><%= format_date_full(@selected_date) %></h2>
    <p class="text-sm text-base-content/70">
      <%= day_summary(@day_meals, @day_shopping_items) %>
    </p>
  </div>

  <!-- Meal Slots (scrollable) -->
  <div class="flex-1 overflow-y-auto">
    <div class="p-4 space-y-4">
      <%= for meal_type <- [:breakfast, :lunch, :dinner, :snack] do %>
        <div class="space-y-2">
          <h3 class="text-xs font-semibold uppercase text-base-content/60 tracking-wider">
            <%= meal_type %>
          </h3>

          <%= if meal = get_meal(@day_meals, meal_type) do %>
            <.focus_meal_card meal={meal} />
          <% else %>
            <button
              class="w-full p-4 rounded-xl border-2 border-dashed border-base-300 text-base-content/50 hover:border-primary hover:text-primary transition-colors"
              phx-click="open_quick_picker"
              phx-value-slot={meal_type}
            >
              <.icon name="hero-plus" class="w-5 h-5 mx-auto mb-1" />
              <span class="text-sm">Add <%= meal_type %></span>
            </button>
          <% end %>
        </div>
      <% end %>
    </div>
  </div>

  <!-- Bottom Bar -->
  <div class="sticky bottom-0 bg-base-100 border-t border-base-300 p-3 flex items-center justify-between">
    <div class="flex items-center gap-2">
      <.icon name="hero-shopping-cart" class="w-5 h-5 text-base-content/60" />
      <%= if length(@day_shopping_items) > 0 do %>
        <span class="text-sm">
          <span class="font-medium"><%= length(@day_shopping_items) %></span>
          items needed
        </span>
      <% else %>
        <span class="text-sm text-success">All ingredients available</span>
      <% end %>
    </div>

    <button class="btn btn-primary btn-sm" phx-click="generate_shopping_list">
      <.icon name="hero-clipboard-document-list" class="w-4 h-4" />
      Shopping List
    </button>
  </div>
</div>
```

### Focus Meal Card Component

```heex
<div
  class="bg-base-200 rounded-xl p-4 relative overflow-hidden"
  phx-hook="SwipeableMeal"
  id={"meal-#{@meal.id}"}
  data-meal-id={@meal.id}
>
  <!-- Swipe actions (hidden, revealed on swipe) -->
  <div class="absolute inset-y-0 left-0 w-20 bg-error flex items-center justify-center -translate-x-full swipe-action-left">
    <.icon name="hero-trash" class="w-6 h-6 text-error-content" />
  </div>
  <div class="absolute inset-y-0 right-0 w-20 bg-warning flex items-center justify-center translate-x-full swipe-action-right">
    <.icon name="hero-arrow-path" class="w-6 h-6 text-warning-content" />
  </div>

  <!-- Main content -->
  <div class="flex items-start gap-3">
    <!-- Recipe image -->
    <%= if @meal.recipe.image_url do %>
      <img
        src={@meal.recipe.image_url}
        class="w-16 h-16 rounded-lg object-cover flex-shrink-0"
      />
    <% else %>
      <div class="w-16 h-16 rounded-lg bg-base-300 flex items-center justify-center flex-shrink-0">
        <.icon name="hero-photo" class="w-8 h-8 text-base-content/30" />
      </div>
    <% end %>

    <!-- Recipe info -->
    <div class="flex-1 min-w-0">
      <div class="flex items-start justify-between gap-2">
        <h4 class="font-medium truncate"><%= @meal.recipe.name %></h4>
        <.availability_badge meal={@meal} />
      </div>

      <div class="flex items-center gap-3 mt-1 text-sm text-base-content/60">
        <span><%= @meal.servings %> servings</span>
        <span>•</span>
        <span><%= @meal.recipe.total_time_minutes %> min</span>
      </div>

      <!-- Notes (if present) -->
      <%= if @meal.notes do %>
        <p class="text-sm text-base-content/70 mt-2 italic">
          "<%= @meal.notes %>"
        </p>
      <% end %>
    </div>
  </div>

  <!-- Quick actions -->
  <div class="flex items-center gap-2 mt-3 pt-3 border-t border-base-300">
    <button
      class="btn btn-ghost btn-xs"
      phx-click="swap_meal"
      phx-value-id={@meal.id}
    >
      <.icon name="hero-arrow-path" class="w-4 h-4" />
      Swap
    </button>
    <button
      class="btn btn-ghost btn-xs"
      phx-click="clear_meal"
      phx-value-id={@meal.id}
    >
      <.icon name="hero-trash" class="w-4 h-4" />
      Clear
    </button>
    <button
      class="btn btn-ghost btn-xs"
      phx-click="toggle_notes"
      phx-value-id={@meal.id}
    >
      <.icon name="hero-chat-bubble-left" class="w-4 h-4" />
      Notes
    </button>
    <div class="flex-1"></div>
    <button
      class={[
        "btn btn-xs",
        if(@meal.status == :completed, do: "btn-success", else: "btn-ghost")
      ]}
      phx-click="mark_complete"
      phx-value-id={@meal.id}
    >
      <.icon name="hero-check" class="w-4 h-4" />
    </button>
  </div>
</div>
```

### Quick Recipe Picker (Bottom Sheet)

```heex
<div
  :if={@show_quick_picker}
  class="fixed inset-0 z-50"
  phx-click-away="close_quick_picker"
>
  <!-- Backdrop -->
  <div class="absolute inset-0 bg-black/50" phx-click="close_quick_picker"></div>

  <!-- Bottom Sheet -->
  <div class="absolute bottom-0 left-0 right-0 bg-base-100 rounded-t-3xl max-h-[80vh] flex flex-col animate-slide-up">
    <!-- Handle -->
    <div class="flex justify-center py-3">
      <div class="w-12 h-1.5 bg-base-300 rounded-full"></div>
    </div>

    <!-- Header -->
    <div class="px-4 pb-3 border-b border-base-300">
      <h3 class="font-bold text-lg">
        Add <%= String.capitalize(to_string(@quick_picker_slot)) %>
      </h3>
      <p class="text-sm text-base-content/70">
        <%= format_date(@selected_date) %>
      </p>
    </div>

    <!-- Search -->
    <div class="px-4 py-3">
      <input
        type="text"
        placeholder="Search recipes..."
        class="input input-bordered input-sm w-full"
        phx-change="search_recipes"
        phx-debounce="200"
        name="query"
      />
    </div>

    <!-- Recipe Lists -->
    <div class="flex-1 overflow-y-auto px-4 pb-4">
      <!-- Recent Recipes -->
      <%= if @recent_recipes != [] do %>
        <div class="mb-4">
          <h4 class="text-xs font-semibold uppercase text-base-content/60 mb-2">
            Recently Used
          </h4>
          <div class="space-y-2">
            <%= for recipe <- Enum.take(@recent_recipes, 5) do %>
              <.quick_picker_item recipe={recipe} />
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Favorites -->
      <%= if @favorite_recipes != [] do %>
        <div class="mb-4">
          <h4 class="text-xs font-semibold uppercase text-base-content/60 mb-2">
            Favorites
          </h4>
          <div class="space-y-2">
            <%= for recipe <- Enum.take(@favorite_recipes, 5) do %>
              <.quick_picker_item recipe={recipe} />
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- All Recipes -->
      <div>
        <h4 class="text-xs font-semibold uppercase text-base-content/60 mb-2">
          All Recipes
        </h4>
        <div class="space-y-2">
          <%= for recipe <- @filtered_recipes do %>
            <.quick_picker_item recipe={recipe} />
          <% end %>
        </div>
      </div>
    </div>
  </div>
</div>
```

### Desktop Layout (≥1024px)

```heex
<div class="flex h-[calc(100vh-4rem)]">
  <!-- Main Content -->
  <div class="flex-1 flex flex-col">
    <!-- Week Navigation -->
    <div class="bg-base-200 px-6 py-4 border-b border-base-300">
      <div class="flex items-center justify-between max-w-3xl mx-auto">
        <button class="btn btn-ghost btn-sm" phx-click="prev_week">
          <.icon name="hero-chevron-left" class="w-5 h-5" />
          Previous
        </button>

        <div class="flex gap-2">
          <%= for {date, day_name} <- week_days(@week_start) do %>
            <button
              class={[
                "flex flex-col items-center py-3 px-4 rounded-xl transition-all min-w-[80px]",
                cond do
                  date == @selected_date -> "bg-primary text-primary-content"
                  date == Date.utc_today() -> "bg-primary/20"
                  true -> "hover:bg-base-300"
                end
              ]}
              phx-click="select_day"
              phx-value-date={Date.to_iso8601(date)}
            >
              <span class="text-sm opacity-70"><%= day_name %></span>
              <span class="text-2xl font-bold"><%= date.day %></span>
              <div class="flex gap-1 mt-1">
                <%= for meal_type <- [:breakfast, :lunch, :dinner] do %>
                  <span class={[
                    "w-2 h-2 rounded-full",
                    if(has_meal?(@week_meals, date, meal_type), do: "bg-success", else: "bg-base-content/20")
                  ]}></span>
                <% end %>
              </div>
            </button>
          <% end %>
        </div>

        <button class="btn btn-ghost btn-sm" phx-click="next_week">
          Next
          <.icon name="hero-chevron-right" class="w-5 h-5" />
        </button>
      </div>
    </div>

    <!-- Day Content -->
    <div class="flex-1 overflow-y-auto">
      <div class="max-w-2xl mx-auto p-6">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h2 class="text-2xl font-bold"><%= format_date_full(@selected_date) %></h2>
            <p class="text-base-content/70"><%= day_summary(@day_meals, @day_shopping_items) %></p>
          </div>

          <div class="flex gap-2">
            <button class="btn btn-outline btn-sm" phx-click="auto_fill_day">
              <.icon name="hero-sparkles" class="w-4 h-4" />
              Auto-fill
            </button>
            <button class="btn btn-outline btn-sm" phx-click="copy_previous_day">
              <.icon name="hero-document-duplicate" class="w-4 h-4" />
              Copy Yesterday
            </button>
          </div>
        </div>

        <div class="space-y-4">
          <%= for meal_type <- [:breakfast, :lunch, :dinner, :snack] do %>
            <.focus_meal_slot_desktop
              meal_type={meal_type}
              meal={get_meal(@day_meals, meal_type)}
            />
          <% end %>
        </div>
      </div>
    </div>
  </div>

  <!-- Right Sidebar: Grocery Impact -->
  <div class="w-80 border-l border-base-300 bg-base-200/50 p-6">
    <h3 class="font-bold mb-4">Grocery Impact</h3>

    <div class="space-y-4">
      <!-- Day Summary -->
      <div class="bg-base-100 rounded-xl p-4">
        <h4 class="text-sm font-medium text-base-content/70 mb-2">Today's Needs</h4>
        <%= if @day_shopping_items == [] do %>
          <div class="flex items-center gap-2 text-success">
            <.icon name="hero-check-circle" class="w-5 h-5" />
            <span>All ingredients available!</span>
          </div>
        <% else %>
          <ul class="space-y-2">
            <%= for item <- @day_shopping_items do %>
              <li class="flex items-center gap-2 text-sm">
                <.icon name="hero-shopping-cart" class="w-4 h-4 text-warning" />
                <span><%= item.name %></span>
                <span class="text-base-content/50">(<%= item.quantity %> <%= item.unit %>)</span>
              </li>
            <% end %>
          </ul>
        <% end %>
      </div>

      <!-- Week Summary -->
      <div class="bg-base-100 rounded-xl p-4">
        <h4 class="text-sm font-medium text-base-content/70 mb-2">This Week</h4>
        <div class="space-y-2">
          <div class="flex justify-between text-sm">
            <span>Meals planned</span>
            <span class="font-medium"><%= count_week_meals(@week_meals) %></span>
          </div>
          <div class="flex justify-between text-sm">
            <span>Shopping items needed</span>
            <span class="font-medium"><%= length(@week_shopping_items) %></span>
          </div>
          <div class="flex justify-between text-sm">
            <span>Recipes ready to make</span>
            <span class="font-medium text-success"><%= count_ready_meals(@week_meals) %></span>
          </div>
        </div>
      </div>

      <!-- Quick Actions -->
      <div class="space-y-2">
        <button class="btn btn-primary w-full" phx-click="generate_shopping_list">
          <.icon name="hero-clipboard-document-list" class="w-4 h-4" />
          Generate Shopping List
        </button>
        <button class="btn btn-outline w-full" phx-click="repeat_last_week">
          <.icon name="hero-arrow-path" class="w-4 h-4" />
          Repeat Last Week
        </button>
      </div>
    </div>
  </div>
</div>
```

### JavaScript Hook: Swipeable Meal Card

```javascript
// assets/js/hooks/swipeable_meal.js
export const SwipeableMeal = {
  mounted() {
    this.startX = 0;
    this.currentX = 0;
    this.threshold = 80;

    this.el.addEventListener('touchstart', (e) => this.handleTouchStart(e));
    this.el.addEventListener('touchmove', (e) => this.handleTouchMove(e));
    this.el.addEventListener('touchend', (e) => this.handleTouchEnd(e));
  },

  handleTouchStart(e) {
    this.startX = e.touches[0].clientX;
  },

  handleTouchMove(e) {
    this.currentX = e.touches[0].clientX;
    const diff = this.currentX - this.startX;

    // Limit swipe distance
    const clampedDiff = Math.max(-this.threshold, Math.min(this.threshold, diff));

    this.el.style.transform = `translateX(${clampedDiff}px)`;
  },

  handleTouchEnd(e) {
    const diff = this.currentX - this.startX;

    if (diff < -this.threshold) {
      // Swipe left - delete
      this.pushEvent("clear_meal", { id: this.el.dataset.mealId });
    } else if (diff > this.threshold) {
      // Swipe right - swap
      this.pushEvent("swap_meal", { id: this.el.dataset.mealId });
    }

    // Reset position
    this.el.style.transform = '';
  }
};
```

## Testing Strategy

### Unit Tests

```elixir
describe "focus mode" do
  test "loads today's meals on mount", %{conn: conn} do
    meal = create_meal_plan(scheduled_date: Date.utc_today())
    {:ok, view, _html} = live(conn, ~p"/meal-planner?layout=focus")

    assert has_element?(view, "[data-meal-id='#{meal.id}']")
  end

  test "navigates between days", %{conn: conn} do
    tomorrow = Date.add(Date.utc_today(), 1)
    meal = create_meal_plan(scheduled_date: tomorrow)

    {:ok, view, _html} = live(conn, ~p"/meal-planner?layout=focus")
    view |> element("[phx-value-date='#{tomorrow}']") |> render_click()

    assert has_element?(view, "[data-meal-id='#{meal.id}']")
  end

  test "shows shopping impact for day", %{conn: conn} do
    recipe = create_recipe_with_missing_ingredients()
    create_meal_plan(recipe: recipe)

    {:ok, view, _html} = live(conn, ~p"/meal-planner?layout=focus")

    assert has_element?(view, "[data-testid='shopping-needed']")
  end
end
```

## Dependencies

- Existing meal planning domain logic
- Touch event handling (JavaScript hooks)
- No new external dependencies

## Rollout Plan

1. **Phase 1:** Core layout and day navigation
2. **Phase 2:** Meal slot cards with basic actions
3. **Phase 3:** Quick recipe picker bottom sheet
4. **Phase 4:** Swipe gestures (mobile)
5. **Phase 5:** Grocery impact sidebar (desktop)
6. **Phase 6:** Shortcuts (repeat week, copy day)

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Meals added per session | > 3 | Focus mode sessions |
| Time to plan day | < 30s | From page load to last action |
| Repeat usage | > 60% | Users who return to Focus mode |
| Mobile task completion | > 90% | Plans created on mobile |

## References

- [UI Improvements Meal Planner](../docs/ui_improvements_meal_planner.md)
- [Meal Planner Layout Checklist](../docs/meal_planner_layout_checklist.md)
