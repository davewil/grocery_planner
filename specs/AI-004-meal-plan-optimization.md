# AI-004: Meal Plan Optimization (SMT Solver)

## Overview

**Feature:** Intelligent meal planning optimization using SMT (Satisfiability Modulo Theories) solvers
**Priority:** Medium-High
**Epic:** OPT-01 (Meal Planning Optimization)
**Estimated Effort:** 7-10 days

## Problem Statement

Users face decision paralysis when planning meals, especially when trying to:
1. Use up ingredients before they expire
2. Minimize grocery shopping while maximizing meal variety
3. Balance nutrition, time, and preferences

**Current Pain Points:**
- "What do I cook with this random stuff?" anxiety
- Food waste from forgotten expiring ingredients
- Over-shopping due to poor planning
- Manual optimization is cognitively demanding

## User Stories

### US-001: Optimize My Fridge
**As a** user with expiring ingredients
**I want** the system to suggest recipes that use them
**So that** I minimize food waste

**Acceptance Criteria:**
- [ ] Shows recipes prioritizing soon-to-expire ingredients
- [ ] Ranks by number of expiring ingredients used
- [ ] Shows "waste prevention score" for each suggestion
- [ ] Minimizes additional shopping required
- [ ] Respects dietary preferences/restrictions

### US-002: Cook With These Ingredients
**As a** user with specific ingredients
**I want** to find recipes using them
**So that** I cook with what I have

**Acceptance Criteria:**
- [ ] Select multiple ingredients from inventory
- [ ] Find recipes using most/all selected ingredients
- [ ] Show missing ingredients for each recipe
- [ ] Sort by "shopping list size"
- [ ] Handle partial matches gracefully

### US-003: Generate Weekly Meal Plan
**As a** user planning the week
**I want** an optimized meal plan generated
**So that** I shop efficiently and eat well

**Acceptance Criteria:**
- [ ] Generate 7-day meal plan
- [ ] Optimize for ingredient overlap (buy once, use twice)
- [ ] Respect time constraints per day (quick meals on busy days)
- [ ] Avoid recipe repetition
- [ ] Balance nutrition (optional)
- [ ] User can lock/unlock specific days

### US-004: Waste Watch Dashboard
**As a** user monitoring my kitchen
**I want** proactive alerts about expiring food
**So that** I can take action before waste occurs

**Acceptance Criteria:**
- [ ] Dashboard widget shows expiring items
- [ ] "Rescue Plan" button generates optimized suggestions
- [ ] Shows estimated waste cost if not acted upon
- [ ] One-click to add suggested recipe to meal plan

## Technical Specification

### Architecture

```
┌─────────────────┐                    ┌──────────────────┐
│  Elixir/Phoenix │     HTTP/JSON      │  Python/FastAPI  │
│   (LiveView)    │◄──────────────────►│   (Z3 Solver)    │
└────────┬────────┘                    └────────┬─────────┘
         │                                      │
         │  1. Prepare problem                  │
         │     (inventory, recipes,             │
         │      constraints)                    │
         │                                      │
         ▼                                      ▼
┌─────────────────┐                    ┌──────────────────┐
│   PostgreSQL    │                    │   Z3 SMT Solver  │
│   (Data)        │                    │   (Optimization) │
└─────────────────┘                    └──────────────────┘
```

### SMT Problem Formulation

#### Variables

For each recipe $r$ in candidate set $R$:
- $x_r \in \{0, 1\}$ — Boolean: is recipe selected?

For each day $d$ in planning horizon $D$:
- $y_{r,d} \in \{0, 1\}$ — Boolean: is recipe $r$ assigned to day $d$?

For each ingredient $i$:
- $used_i$ — Integer: total quantity used across selected recipes
- $buy_i$ — Integer: quantity to purchase (if needed)

#### Constraints

**1. Recipe Selection**
```
∀r: x_r = 1 ⟺ ∃d: y_{r,d} = 1
```

**2. One Recipe Per Meal Slot**
```
∀d, slot: Σ_r y_{r,d,slot} ≤ 1
```

**3. Inventory Constraints**
```
∀i: used_i ≤ available_i + buy_i
```

**4. Expiration Priority**
```
∀i where expires_in(i) ≤ threshold:
  used_i ≥ min_usage_i  (soft constraint with high weight)
```

**5. No Repetition**
```
∀r: Σ_d y_{r,d} ≤ 1  (within planning window)
```

#### Objective Function

**Multi-objective optimization:**

```
Maximize:
  w1 × Σ_r (x_r × expiring_score_r)     # Use expiring ingredients
  - w2 × Σ_i buy_i                       # Minimize shopping
  + w3 × variety_score                   # Maximize variety
  - w4 × Σ_d time_penalty_d             # Respect time budgets
```

Where:
- `expiring_score_r` = sum of (1/days_until_expiry) for ingredients in recipe r
- `variety_score` = count of unique cuisines/categories
- `time_penalty_d` = max(0, recipe_time - available_time_d)

### Python Service Endpoints

#### Optimize Meal Plan

**Endpoint:** `POST /api/v1/optimize/meal-plan`

**Request:**
```json
{
  "version": "1.0",
  "request_id": "uuid",
  "account_id": "uuid",
  "problem": {
    "planning_horizon": {
      "start_date": "2026-01-13",
      "days": 7,
      "meal_types": ["dinner"]
    },
    "inventory": [
      {
        "ingredient_id": "uuid",
        "name": "Chicken Breast",
        "quantity": 2,
        "unit": "lb",
        "days_until_expiry": 3
      }
    ],
    "recipes": [
      {
        "id": "uuid",
        "name": "Grilled Chicken Salad",
        "prep_time": 15,
        "cook_time": 20,
        "ingredients": [
          {"ingredient_id": "uuid", "quantity": 1, "unit": "lb"}
        ],
        "tags": ["healthy", "quick"],
        "is_favorite": true
      }
    ],
    "constraints": {
      "max_shopping_items": 10,
      "time_budgets": {
        "2026-01-13": 30,
        "2026-01-14": 60,
        "2026-01-15": 45
      },
      "locked_meals": [
        {"date": "2026-01-15", "recipe_id": "uuid"}
      ],
      "excluded_recipes": ["uuid"],
      "dietary": ["gluten-free"]
    },
    "weights": {
      "expiring_priority": 0.4,
      "shopping_minimization": 0.3,
      "variety": 0.2,
      "time_fit": 0.1
    }
  }
}
```

**Response:**
```json
{
  "version": "1.0",
  "request_id": "uuid",
  "status": "optimal",
  "solve_time_ms": 450,
  "solution": {
    "meal_plan": [
      {
        "date": "2026-01-13",
        "meal_type": "dinner",
        "recipe_id": "uuid",
        "recipe_name": "Grilled Chicken Salad"
      }
    ],
    "shopping_list": [
      {
        "ingredient_id": "uuid",
        "name": "Romaine Lettuce",
        "quantity": 1,
        "unit": "head"
      }
    ],
    "metrics": {
      "expiring_ingredients_used": 3,
      "total_expiring_ingredients": 5,
      "waste_prevented_value": 12.50,
      "shopping_items_count": 4,
      "estimated_shopping_cost": 18.75,
      "variety_score": 0.85
    },
    "explanation": [
      "Selected 'Grilled Chicken Salad' for Monday to use chicken expiring in 3 days",
      "Avoided 'Pasta Carbonara' due to time constraint (60 min > 30 min budget)"
    ]
  }
}
```

#### Quick Suggestions (Lighter endpoint)

**Endpoint:** `POST /api/v1/optimize/suggestions`

**Request:**
```json
{
  "version": "1.0",
  "request_id": "uuid",
  "account_id": "uuid",
  "mode": "use_expiring",
  "ingredients": ["uuid1", "uuid2"],
  "limit": 5
}
```

**Response:**
```json
{
  "version": "1.0",
  "request_id": "uuid",
  "suggestions": [
    {
      "recipe_id": "uuid",
      "recipe_name": "Stir Fry",
      "score": 0.92,
      "expiring_used": ["Chicken", "Bell Peppers"],
      "missing": ["Soy Sauce"],
      "reason": "Uses 2 expiring ingredients, only 1 item to buy"
    }
  ]
}
```

### Z3 Solver Implementation

```python
from z3 import *

class MealPlanOptimizer:
    def __init__(self, problem: dict):
        self.problem = problem
        self.solver = Optimize()
        self.recipe_vars = {}
        self.day_recipe_vars = {}

    def build_model(self):
        recipes = self.problem["recipes"]
        days = self.problem["planning_horizon"]["days"]

        # Create decision variables
        for recipe in recipes:
            rid = recipe["id"]
            self.recipe_vars[rid] = Bool(f"select_{rid}")

            for day in range(days):
                self.day_recipe_vars[(rid, day)] = Bool(f"assign_{rid}_{day}")

        # Add constraints
        self._add_selection_constraints()
        self._add_one_per_slot_constraints()
        self._add_inventory_constraints()
        self._add_time_constraints()
        self._add_locked_meal_constraints()

        # Add objective
        self._add_objective()

    def _add_selection_constraints(self):
        """Recipe is selected iff assigned to some day"""
        for rid, selected in self.recipe_vars.items():
            days = self.problem["planning_horizon"]["days"]
            assigned_any = Or([
                self.day_recipe_vars[(rid, d)]
                for d in range(days)
            ])
            self.solver.add(selected == assigned_any)

    def _add_one_per_slot_constraints(self):
        """At most one recipe per day"""
        days = self.problem["planning_horizon"]["days"]
        for day in range(days):
            day_vars = [
                self.day_recipe_vars[(rid, day)]
                for rid in self.recipe_vars.keys()
            ]
            self.solver.add(AtMost(*day_vars, 1))

    def _add_objective(self):
        """Multi-objective: expiring usage - shopping + variety"""
        weights = self.problem.get("weights", {})
        w_expiring = weights.get("expiring_priority", 0.4)
        w_shopping = weights.get("shopping_minimization", 0.3)

        # Expiring score
        expiring_score = Sum([
            If(self.recipe_vars[r["id"]], r.get("expiring_score", 0), 0)
            for r in self.problem["recipes"]
        ])

        # Shopping penalty (simplified)
        shopping_penalty = self._compute_shopping_penalty()

        # Combined objective
        self.solver.maximize(
            w_expiring * expiring_score - w_shopping * shopping_penalty
        )

    def solve(self, timeout_ms: int = 5000) -> dict:
        self.solver.set("timeout", timeout_ms)

        if self.solver.check() == sat:
            model = self.solver.model()
            return self._extract_solution(model)
        else:
            return {"status": "no_solution"}
```

### Elixir Integration

**Module:** `GroceryPlanner.AI.MealOptimizer`

```elixir
defmodule GroceryPlanner.AI.MealOptimizer do
  @moduledoc """
  Client for meal plan optimization service.
  """

  alias GroceryPlanner.{Inventory, Recipes, MealPlanning}

  @doc """
  Generates an optimized meal plan for the given date range.
  """
  @spec optimize_meal_plan(Account.t(), Date.t(), integer(), Keyword.t()) ::
    {:ok, optimization_result()} | {:error, term()}
  def optimize_meal_plan(account, start_date, days, opts \\ []) do
    problem = build_optimization_problem(account, start_date, days, opts)

    case call_optimizer_service(problem) do
      {:ok, %{"status" => "optimal"} = result} ->
        {:ok, parse_solution(result)}
      {:ok, %{"status" => "no_solution"}} ->
        {:error, :no_feasible_solution}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Quick suggestions for using expiring ingredients.
  """
  @spec suggest_for_expiring(Account.t(), integer()) :: [suggestion()]
  def suggest_for_expiring(account, limit \\ 5) do
    expiring = Inventory.get_expiring_items(account, days: 7)
    recipes = Recipes.list_recipes(account)

    # Call lighter suggestion endpoint
    call_suggestions_service(%{
      mode: "use_expiring",
      ingredients: Enum.map(expiring, & &1.grocery_item_id),
      recipes: format_recipes(recipes),
      limit: limit
    })
  end

  defp build_optimization_problem(account, start_date, days, opts) do
    inventory = Inventory.list_inventory_entries(account)
    recipes = Recipes.list_recipes(account)

    %{
      planning_horizon: %{
        start_date: Date.to_iso8601(start_date),
        days: days,
        meal_types: Keyword.get(opts, :meal_types, ["dinner"])
      },
      inventory: format_inventory(inventory),
      recipes: format_recipes(recipes),
      constraints: build_constraints(opts),
      weights: Keyword.get(opts, :weights, default_weights())
    }
  end
end
```

### LiveView Integration

**Waste Watch Widget:**

```elixir
defmodule GroceryPlannerWeb.DashboardLive do
  # ... existing code ...

  def handle_event("optimize_fridge", _params, socket) do
    case AI.MealOptimizer.suggest_for_expiring(socket.assigns.account, 5) do
      {:ok, suggestions} ->
        {:noreply, assign(socket, :rescue_suggestions, suggestions)}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Couldn't generate suggestions")}
    end
  end

  def handle_event("apply_suggestion", %{"recipe-id" => recipe_id, "date" => date}, socket) do
    # Add to meal plan
    MealPlanning.create_meal_plan(%{
      recipe_id: recipe_id,
      scheduled_date: Date.from_iso8601!(date),
      meal_type: :dinner,
      account_id: socket.assigns.account.id
    })

    {:noreply,
      socket
      |> put_flash(:info, "Added to meal plan!")
      |> push_navigate(to: ~p"/meal-planner")}
  end
end
```

## UI/UX Specifications

### Waste Watch Widget

```heex
<.section title="Waste Watch" class="bg-warning/10 border-warning">
  <:header_actions>
    <button class="btn btn-sm btn-warning" phx-click="optimize_fridge">
      <.icon name="hero-sparkles" class="w-4 h-4" />
      Get Rescue Plan
    </button>
  </:header_actions>

  <div class="space-y-4">
    <!-- Expiring items summary -->
    <div class="flex items-center gap-4">
      <div class="stat-value text-warning"><%= length(@expiring_items) %></div>
      <div>
        <p class="font-medium">Items expiring soon</p>
        <p class="text-sm text-base-content/70">
          ~<%= @expiring_value %> at risk
        </p>
      </div>
    </div>

    <!-- Rescue suggestions (when loaded) -->
    <%= if @rescue_suggestions do %>
      <div class="divider">Suggested Recipes</div>
      <div class="space-y-2">
        <%= for suggestion <- @rescue_suggestions do %>
          <div class="flex items-center justify-between p-3 bg-base-100 rounded-lg">
            <div>
              <p class="font-medium"><%= suggestion.recipe_name %></p>
              <p class="text-sm text-success">
                Uses: <%= Enum.join(suggestion.expiring_used, ", ") %>
              </p>
            </div>
            <button
              class="btn btn-sm btn-primary"
              phx-click="apply_suggestion"
              phx-value-recipe-id={suggestion.recipe_id}
              phx-value-date={Date.to_iso8601(Date.utc_today())}
            >
              Add to Today
            </button>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>
</.section>
```

### Weekly Planner Optimization

```heex
<div class="flex items-center gap-2 mb-4">
  <button class="btn btn-outline btn-sm" phx-click="show_optimize_modal">
    <.icon name="hero-sparkles" class="w-4 h-4" />
    Auto-Fill Week
  </button>
</div>

<!-- Optimization Modal -->
<.modal :if={@show_optimize_modal} id="optimize-modal">
  <h3 class="text-lg font-bold mb-4">Optimize Your Week</h3>

  <form phx-submit="run_optimization">
    <div class="space-y-4">
      <!-- Priorities -->
      <div>
        <label class="label">Optimization Priority</label>
        <div class="flex flex-wrap gap-2">
          <label class="cursor-pointer flex items-center gap-2">
            <input type="radio" name="priority" value="waste" class="radio radio-primary" checked />
            <span>Minimize Waste</span>
          </label>
          <label class="cursor-pointer flex items-center gap-2">
            <input type="radio" name="priority" value="shopping" class="radio radio-primary" />
            <span>Minimize Shopping</span>
          </label>
          <label class="cursor-pointer flex items-center gap-2">
            <input type="radio" name="priority" value="variety" class="radio radio-primary" />
            <span>Maximize Variety</span>
          </label>
        </div>
      </div>

      <!-- Time budgets -->
      <div>
        <label class="label">Time Budget Per Day</label>
        <select name="time_budget" class="select select-bordered w-full">
          <option value="30">Quick (30 min)</option>
          <option value="45">Medium (45 min)</option>
          <option value="60" selected>Standard (60 min)</option>
          <option value="90">Extended (90 min)</option>
        </select>
      </div>

      <!-- Locked days -->
      <div>
        <label class="label">Keep Existing Meals</label>
        <div class="flex flex-wrap gap-2">
          <%= for {day, meals} <- @existing_meals do %>
            <label class="cursor-pointer">
              <input type="checkbox" name="locked[]" value={day} class="checkbox checkbox-sm" />
              <span class="ml-1 text-sm"><%= day_name(day) %></span>
            </label>
          <% end %>
        </div>
      </div>
    </div>

    <div class="modal-action">
      <button type="button" class="btn btn-ghost" phx-click="hide_optimize_modal">
        Cancel
      </button>
      <button type="submit" class="btn btn-primary">
        <.icon name="hero-sparkles" class="w-4 h-4" />
        Generate Plan
      </button>
    </div>
  </form>
</.modal>
```

## Testing Strategy

### Unit Tests

```elixir
defmodule GroceryPlanner.AI.MealOptimizerTest do
  use GroceryPlanner.DataCase

  describe "optimize_meal_plan/4" do
    test "generates plan using expiring ingredients first" do
      # Setup: chicken expiring in 2 days, beef in 10 days
      chicken = create_inventory_entry(days_until_expiry: 2)
      beef = create_inventory_entry(days_until_expiry: 10)

      chicken_recipe = create_recipe(ingredients: [chicken.grocery_item])
      beef_recipe = create_recipe(ingredients: [beef.grocery_item])

      {:ok, result} = MealOptimizer.optimize_meal_plan(account, today, 3)

      # Chicken recipe should be selected first
      first_meal = hd(result.meal_plan)
      assert first_meal.recipe_id == chicken_recipe.id
    end

    test "respects time constraints" do
      quick_recipe = create_recipe(total_time: 30)
      slow_recipe = create_recipe(total_time: 90)

      opts = [time_budgets: %{today => 45}]
      {:ok, result} = MealOptimizer.optimize_meal_plan(account, today, 1, opts)

      assert hd(result.meal_plan).recipe_id == quick_recipe.id
    end
  end
end
```

### Integration Tests (Python)

```python
def test_optimizer_basic():
    problem = {
        "planning_horizon": {"start_date": "2026-01-13", "days": 3},
        "inventory": [
            {"ingredient_id": "1", "name": "Chicken", "quantity": 2, "days_until_expiry": 2}
        ],
        "recipes": [
            {"id": "r1", "name": "Chicken Salad", "ingredients": [{"ingredient_id": "1", "quantity": 1}]}
        ],
        "constraints": {},
        "weights": {"expiring_priority": 1.0}
    }

    response = client.post("/api/v1/optimize/meal-plan", json={"problem": problem})
    assert response.status_code == 200
    assert response.json()["status"] == "optimal"
    assert len(response.json()["solution"]["meal_plan"]) > 0

def test_optimizer_respects_constraints():
    # Test that locked meals aren't changed
    # Test that time budgets are respected
    pass
```

## Dependencies

### Python Service
- `z3-solver>=4.12.0`
- `fastapi>=0.100.0`

### Elixir App
- `req` (HTTP client)
- `jason` (JSON)

## Configuration

```bash
# Elixir
AI_SERVICE_URL=http://grocery-planner-ai.internal:8000
MEAL_OPTIMIZATION_ENABLED=true
OPTIMIZATION_TIMEOUT_MS=5000

# Python
Z3_TIMEOUT_MS=5000
MAX_RECIPES_FOR_OPTIMIZATION=100
```

## Rollout Plan

1. **Phase 1:** Deploy Z3 solver service
2. **Phase 2:** Quick suggestions endpoint (lighter)
3. **Phase 3:** Waste Watch widget on dashboard
4. **Phase 4:** Full weekly optimization
5. **Phase 5:** Time budget and constraint UI

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Optimization solve rate | > 95% | Solutions found / requests |
| Suggestion acceptance | > 40% | Applied / shown |
| Waste reduction | -20% | Expired items month-over-month |
| Solve time (p95) | < 3s | Service latency |

## References

- [Z3 Theorem Prover](https://github.com/Z3Prover/z3)
- [SMT-LIB Standard](http://smtlib.cs.uiowa.edu/)
- [SMT Solver Recipe Optimization](../docs/smt_solver_recipe_optimization.md)
- [AI Backlog - OPT-01](../docs/ai_backlog.md)
