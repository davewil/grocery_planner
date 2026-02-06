# AI-004 Meal Plan Optimization - Implementation Plan

## Overview

Implement intelligent meal planning optimization across 4 user stories. Phase 1 focuses on US-001 (Optimize My Fridge) and US-002 (Cook With These Ingredients) using enhanced Elixir scoring. Phase 2 adds Z3 SMT solver for US-003 (Weekly Meal Plan) and the Waste Watch widget (US-004).

## Decisions

- **US-001 + US-002 first**, then US-003 + US-004
- **Z3 only for weekly plans** (US-003). US-001/US-002 use Elixir scoring/ranking
- **Waste Watch on both** dashboard and meal planner

## Existing Infrastructure

- **Dashboard** already loads `ExpirationAlerts` and `RecipeSuggestions` services
- **MealPlanner** has `auto_fill_week`, recipe search, grocery impact calculations
- **Recipe** has `can_make`, `ingredient_availability`, `dietary_needs`, `is_waste_risk`, follow-up chains
- **InventoryEntry** has `use_by_date`, `days_until_expiry`, `is_expiring_soon` calculations
- **GroceryImpact** calculates missing ingredients for meal plans vs inventory
- **Python service** has FastAPI with 15 endpoints, no optimization code yet

---

## Phase 1: US-001 + US-002 (Elixir Scoring)

### Step 1: Create MealOptimizer Elixir Module

**File:** `lib/grocery_planner/ai/meal_optimizer.ex`

Create `GroceryPlanner.AI.MealOptimizer` with two public functions:

1. **`suggest_for_expiring/3`** (US-001: Optimize My Fridge)
   - Input: `account_id`, `actor`, `opts \\ []`
   - Loads expiring inventory entries (next 7 days) via `Inventory.list_inventory_entries_filtered`
   - Loads all recipes with `recipe_ingredients` and `grocery_item` preloaded
   - Scores each recipe by:
     - `expiring_score`: sum of `(1 / days_until_expiry)` for each recipe ingredient that matches an expiring item
     - `availability_score`: percentage of ingredients already in stock
     - `shopping_penalty`: count of missing ingredients
     - `waste_prevention_score`: normalized composite (expiring_score * 0.5 + availability * 0.3 - shopping * 0.2)
   - Returns top N suggestions with: `recipe`, `waste_prevention_score`, `expiring_used` (list of names), `missing` (list of names), `reason` (generated explanation string)

2. **`suggest_for_ingredients/4`** (US-002: Cook With These)
   - Input: `account_id`, `ingredient_ids`, `actor`, `opts \\ []`
   - Loads specified grocery items and their inventory entries
   - Loads all recipes with ingredients
   - Scores by:
     - `match_score`: count of selected ingredients used / total recipe ingredients
     - `missing_count`: ingredients not in `ingredient_ids`
   - Sort by match_score desc, then missing_count asc
   - Returns suggestions with: `recipe`, `match_score`, `matched` (names), `missing` (names)

**Dependencies:** Uses existing domain code interfaces with `authorize?: false` for system queries. No new Ash resources needed.

### Step 2: Tests for MealOptimizer

**File:** `test/grocery_planner/ai/meal_optimizer_test.exs`

Tests:
- `suggest_for_expiring/3`:
  - Prioritizes recipes using soon-to-expire ingredients over later ones
  - Returns waste_prevention_score for each suggestion
  - Respects limit option
  - Returns empty list when no expiring items
  - Excludes recipes that need mostly non-stocked ingredients
- `suggest_for_ingredients/4`:
  - Returns recipes sorted by match score
  - Shows missing ingredients for partial matches
  - Returns empty list when no recipes match any ingredient
  - Handles single ingredient selection

### Step 3: Dashboard Waste Watch Widget

**Files:**
- `lib/grocery_planner_web/live/dashboard_live.ex` - Add `rescue_suggestions` assign, `handle_event("optimize_fridge")`, `handle_event("apply_suggestion")`
- `lib/grocery_planner_web/live/dashboard_live.html.heex` - Add Waste Watch widget section

Widget shows:
- Count of expiring items (already loaded as `@expiring_items`)
- Estimated waste value (sum of `purchase_price` of expiring entries)
- "Get Rescue Plan" button → calls `MealOptimizer.suggest_for_expiring/3`
- Suggestion cards with recipe name, expiring ingredients used, "Add to Plan" button
- "Add to Plan" creates a MealPlan entry for today via `MealPlanning.create_meal_plan/2`

### Step 4: Meal Planner "Cook With These" Feature

**Files:**
- `lib/grocery_planner_web/live/meal_planner_live.ex` - Add ingredient picker modal, suggestion results
- Relevant layout file for button placement

Add to meal planner:
- "Cook With These" button in recipe sidebar
- Modal: multi-select ingredient picker (from inventory items with status :available)
- On submit: calls `MealOptimizer.suggest_for_ingredients/4`
- Results shown in modal with "Add to Day" action for each suggestion
- "Add to Day" creates meal plan entry for the selected/current day

### Step 5: Dashboard + Meal Planner Waste Watch Summary

**Meal Planner integration:**
- Add a collapsible "Waste Watch" banner at top of meal planner when expiring items exist
- Shows count: "3 items expiring this week"
- "See Suggestions" button opens a modal with rescue suggestions (reuses MealOptimizer)
- Quick action: "Auto-fill with rescue recipes" adds top suggestions to empty days

### Step 6: Tests for LiveView Integration

**Files:**
- `test/grocery_planner_web/live/dashboard_live_test.exs` - New or expanded
- `test/grocery_planner_web/live/meal_planner_optimization_test.exs` - New

Dashboard tests:
- Widget shows expiring item count
- "Get Rescue Plan" button loads suggestions
- Suggestion cards display recipe name and expiring ingredients used
- "Add to Plan" creates a meal plan entry

Meal Planner tests:
- "Cook With These" button opens ingredient picker
- Selecting ingredients and submitting shows recipe suggestions
- Suggestions show match score and missing ingredients
- "Add to Day" creates meal plan entry
- Waste Watch banner shows when items expiring

---

## Phase 2: US-003 (Z3 Weekly Optimization) + US-004 (Waste Watch Enhancement)

### Step 7: Python Z3 Optimizer Module

**File:** `python_service/meal_optimizer.py`

Create `MealPlanOptimizer` class using Z3's `Optimize` solver:
- Variables: `x_r` (recipe selected), `y_{r,d}` (recipe assigned to day)
- Constraints: one-per-slot, inventory, time budgets, locked meals, no repetition, dietary
- Objective: weighted sum of expiring usage, shopping minimization, variety, time fit
- `solve(timeout_ms=5000)` → extracts solution from Z3 model

**File:** `python_service/optimization_schemas.py`

Pydantic models:
- `MealPlanOptimizationRequest` - planning horizon, inventory, recipes, constraints, weights
- `MealPlanOptimizationResponse` - meal plan, shopping list, metrics, explanation
- `QuickSuggestionRequest/Response` - lighter models for suggestion endpoint

### Step 8: Python Endpoints

**File:** `python_service/main.py` (add endpoints)

- `POST /api/v1/optimize/meal-plan` - Full weekly optimization via Z3
- `POST /api/v1/optimize/suggestions` - Quick suggestions (Python-side scoring, lighter than Z3)

### Step 9: Python Tests

**File:** `python_service/tests/test_meal_optimizer.py`

Tests:
- Basic optimization with 3 recipes, 3 days → valid plan
- Expiring ingredients prioritized
- Time constraints respected
- Locked meals preserved
- No repetition constraint works
- Solver timeout returns partial/no solution gracefully
- Edge cases: no recipes, all recipes too slow, empty inventory

### Step 10: Elixir Integration for Weekly Optimization

**File:** `lib/grocery_planner/ai/meal_optimizer.ex` (extend)

Add `optimize_weekly_plan/4`:
- Input: `account_id`, `start_date`, `days`, `opts`
- Builds optimization problem from Ash resources (inventory + recipes + existing plans)
- Calls Python service via HTTP (Req)
- Parses response into Elixir structs
- Returns `{:ok, %{meal_plan: [...], shopping_list: [...], metrics: %{...}}}` or `{:error, reason}`

### Step 11: Weekly Optimization UI in Meal Planner

**Files:**
- `lib/grocery_planner_web/live/meal_planner_live.ex` - Add optimization modal

"Auto-Fill Week" button (enhance existing `auto_fill_week`):
- Opens modal with options: priority (waste/shopping/variety), time budget, locked days
- On submit: calls `MealOptimizer.optimize_weekly_plan/4`
- Shows optimization results with metrics (waste prevented, shopping items, variety score)
- "Apply Plan" button creates meal plan entries for each day
- "Regenerate" button re-runs with different weights

### Step 12: US-004 Waste Watch Dashboard Enhancement

Enhance the dashboard widget from Step 3:
- Add estimated waste cost calculation (sum purchase_price of expiring entries)
- Add waste trend indicator (compare to last week/month if historical data exists)
- "Rescue Plan" shows more detailed metrics from optimizer
- One-click "Add to Plan" for each suggestion

### Step 13: Integration Tests

**File:** `test/integration/meal_optimization_integration_test.exs`

Tagged `@tag :integration` (excluded from normal test runs):
- End-to-end: Elixir → Python → Z3 → response parsing
- Verify solution is feasible (all constraints satisfied)
- Verify timeout handling

---

## File Summary

### New Files
1. `lib/grocery_planner/ai/meal_optimizer.ex` - Core optimization module
2. `test/grocery_planner/ai/meal_optimizer_test.exs` - Unit tests
3. `test/grocery_planner_web/live/meal_planner_optimization_test.exs` - LiveView tests
4. `python_service/meal_optimizer.py` - Z3 solver implementation
5. `python_service/optimization_schemas.py` - Pydantic models
6. `python_service/tests/test_meal_optimizer.py` - Python tests

### Modified Files
7. `lib/grocery_planner_web/live/dashboard_live.ex` - Waste Watch widget logic
8. `lib/grocery_planner_web/live/dashboard_live.html.heex` - Waste Watch UI
9. `lib/grocery_planner_web/live/meal_planner_live.ex` - Cook With These + optimization modal
10. `python_service/main.py` - New endpoints
11. `python_service/requirements.txt` - Add z3-solver

### Possibly Modified
12. `lib/grocery_planner/inventory.ex` - May need new code interface for expiring items query
13. `lib/grocery_planner/recipes.ex` - May need recipe query with full ingredient loading

## Implementation Order

```
Phase 1 (Elixir scoring - no Python changes):
  Step 1 → Step 2 → Step 3 → Step 4 → Step 5 → Step 6

Phase 2 (Z3 weekly optimization):
  Step 7 → Step 8 → Step 9 → Step 10 → Step 11 → Step 12 → Step 13
```

Each step produces a working, testable increment. Phase 1 delivers US-001 + US-002 value without Python service changes. Phase 2 adds the heavy optimization.
