"""Meal plan optimization using Z3 SMT solver."""
import logging
import time
from typing import Any

from z3 import Bool, If, Implies, Int, Not, Optimize, Or, Sum, sat

logger = logging.getLogger("grocery-planner-ai.meal_optimizer")


class MealPlanOptimizer:
    """Z3-based meal plan optimizer.

    Variables:
    - select_r: Bool - is recipe r selected?
    - assign_r_d: Bool - is recipe r assigned to day d?
    - buy_i: Int - quantity of ingredient i to purchase

    Constraints:
    - One recipe per day (at most)
    - Recipe selected iff assigned to some day
    - Inventory: used <= available + buy
    - Locked meals preserved
    - No recipe repetition (each recipe at most once)
    - Time budgets per day

    Objective (maximize):
    w1 * expiring_score - w2 * shopping_penalty + w3 * variety_bonus
    """

    def __init__(self, problem: dict[str, Any]):
        self.problem = problem
        self.optimizer = Optimize()
        self.recipe_vars: dict[str, Any] = {}      # recipe_id -> Bool
        self.assign_vars: dict[tuple[str, int], Any] = {}  # (recipe_id, day) -> Bool
        self.buy_vars: dict[str, Any] = {}          # ingredient_id -> Int

    def build_model(self) -> None:
        """Build the Z3 optimization model from the problem definition."""
        recipes = self.problem.get("recipes", [])
        days = self.problem.get("planning_horizon", {}).get("days", 7)

        # Create decision variables
        for recipe in recipes:
            rid = recipe["id"]
            self.recipe_vars[rid] = Bool(f"select_{rid[:8]}")
            for day in range(days):
                self.assign_vars[(rid, day)] = Bool(f"assign_{rid[:8]}_d{day}")

        # Create buy variables for each unique ingredient
        ingredient_ids = set()
        for recipe in recipes:
            for ing in recipe.get("ingredients", []):
                iid = ing["ingredient_id"]
                if iid not in ingredient_ids:
                    ingredient_ids.add(iid)
                    self.buy_vars[iid] = Int(f"buy_{iid[:8]}")
                    self.optimizer.add(self.buy_vars[iid] >= 0)

        self._add_selection_constraints(recipes, days)
        self._add_one_per_slot_constraints(days)
        self._add_no_repetition_constraints(days)
        self._add_locked_meal_constraints(recipes, days)
        self._add_time_constraints(recipes, days)
        self._add_inventory_constraints(recipes)
        self._add_objective(recipes, days)

    def _add_selection_constraints(self, recipes: list, days: int) -> None:
        """Recipe is selected iff assigned to at least one day."""
        for recipe in recipes:
            rid = recipe["id"]
            assigned_any = Or([self.assign_vars[(rid, d)] for d in range(days)])
            self.optimizer.add(self.recipe_vars[rid] == assigned_any)

    def _add_one_per_slot_constraints(self, days: int) -> None:
        """At most one recipe per day."""
        for day in range(days):
            day_vars = [self.assign_vars[(rid, day)] for rid in self.recipe_vars]
            # Sum of booleans <= 1
            self.optimizer.add(Sum([If(v, 1, 0) for v in day_vars]) <= 1)

    def _add_no_repetition_constraints(self, days: int) -> None:
        """Each recipe assigned to at most one day."""
        for rid in self.recipe_vars:
            assigned_days = [self.assign_vars[(rid, d)] for d in range(days)]
            self.optimizer.add(Sum([If(v, 1, 0) for v in assigned_days]) <= 1)

    def _add_locked_meal_constraints(self, recipes: list, days: int) -> None:
        """Preserve locked meals - force assignment."""
        locked = self.problem.get("constraints", {}).get("locked_meals", [])
        start_date = self.problem.get("planning_horizon", {}).get("start_date", "")

        for lock in locked:
            lock_date = lock.get("date", "")
            lock_recipe_id = lock.get("recipe_id", "")

            # Calculate day index from date
            if start_date and lock_date:
                try:
                    from datetime import date as dt_date
                    start = dt_date.fromisoformat(start_date)
                    lock_d = dt_date.fromisoformat(lock_date)
                    day_idx = (lock_d - start).days
                except (ValueError, TypeError):
                    continue
            else:
                continue

            if 0 <= day_idx < days and lock_recipe_id in self.recipe_vars:
                # Force this recipe on this day
                self.optimizer.add(self.assign_vars[(lock_recipe_id, day_idx)] == True)
                # No other recipe on this day
                for rid in self.recipe_vars:
                    if rid != lock_recipe_id:
                        self.optimizer.add(self.assign_vars[(rid, day_idx)] == False)

    def _add_time_constraints(self, recipes: list, days: int) -> None:
        """Respect time budgets per day."""
        time_budgets = self.problem.get("constraints", {}).get("time_budgets", {})
        start_date = self.problem.get("planning_horizon", {}).get("start_date", "")

        if not time_budgets or not start_date:
            return

        try:
            from datetime import date as dt_date, timedelta
            start = dt_date.fromisoformat(start_date)
        except (ValueError, TypeError):
            return

        recipe_map = {r["id"]: r for r in recipes}

        for date_str, budget_minutes in time_budgets.items():
            try:
                budget_date = dt_date.fromisoformat(date_str)
                day_idx = (budget_date - start).days
            except (ValueError, TypeError):
                continue

            if 0 <= day_idx < days:
                for rid, recipe in recipe_map.items():
                    total_time = recipe.get("prep_time", 0) + recipe.get("cook_time", 0)
                    if total_time > budget_minutes:
                        # Recipe too slow for this day
                        self.optimizer.add(self.assign_vars[(rid, day_idx)] == False)

    def _add_inventory_constraints(self, recipes: list) -> None:
        """Ensure used ingredients <= available + buy."""
        inventory = self.problem.get("inventory", [])
        inv_map: dict[str, float] = {}
        for item in inventory:
            iid = item["ingredient_id"]
            inv_map[iid] = inv_map.get(iid, 0) + item.get("quantity", 0)

        # Build usage per ingredient
        for iid in self.buy_vars:
            usage_terms = []
            for recipe in recipes:
                rid = recipe["id"]
                for ing in recipe.get("ingredients", []):
                    if ing["ingredient_id"] == iid:
                        qty = int(ing.get("quantity", 1))
                        usage_terms.append(If(self.recipe_vars[rid], qty, 0))

            if usage_terms:
                total_used = Sum(usage_terms)
                available = int(inv_map.get(iid, 0))
                self.optimizer.add(total_used <= available + self.buy_vars[iid])

    def _add_objective(self, recipes: list, days: int) -> None:
        """Multi-objective: maximize expiring usage - shopping + variety."""
        weights = self.problem.get("weights", {})
        w_expiring = int(weights.get("expiring_priority", 0.4) * 100)
        w_shopping = int(weights.get("shopping_minimization", 0.3) * 100)
        w_variety = int(weights.get("variety", 0.2) * 100)

        # Expiring score: sum of (1/days_until_expiry) scaled to int
        inventory = self.problem.get("inventory", [])
        expiry_map: dict[str, int] = {}
        for item in inventory:
            iid = item["ingredient_id"]
            dte = item.get("days_until_expiry")
            if dte is not None and dte > 0:
                score = max(1, int(100 / dte))  # Higher for sooner expiry
                expiry_map[iid] = max(expiry_map.get(iid, 0), score)

        expiring_terms = []
        for recipe in recipes:
            rid = recipe["id"]
            recipe_expiry = 0
            for ing in recipe.get("ingredients", []):
                recipe_expiry += expiry_map.get(ing["ingredient_id"], 0)
            if recipe_expiry > 0:
                expiring_terms.append(If(self.recipe_vars[rid], recipe_expiry, 0))

        expiring_score = Sum(expiring_terms) if expiring_terms else Int("zero_exp")
        if not expiring_terms:
            self.optimizer.add(expiring_score == 0)

        # Shopping penalty: sum of buy quantities
        shopping_penalty = Sum(list(self.buy_vars.values())) if self.buy_vars else Int("zero_shop")
        if not self.buy_vars:
            self.optimizer.add(shopping_penalty == 0)

        # Variety bonus: count of selected recipes
        variety_terms = [If(v, 1, 0) for v in self.recipe_vars.values()]
        variety_score = Sum(variety_terms) if variety_terms else Int("zero_var")
        if not variety_terms:
            self.optimizer.add(variety_score == 0)

        # Combined objective (all scaled to integers for Z3)
        self.optimizer.maximize(
            w_expiring * expiring_score
            - w_shopping * shopping_penalty
            + w_variety * variety_score
        )

    def solve(self, timeout_ms: int = 5000) -> dict[str, Any]:
        """Solve the optimization problem.

        Returns dict with status, solve_time_ms, and solution (if found).
        """
        self.optimizer.set("timeout", timeout_ms)
        start = time.time()

        try:
            result = self.optimizer.check()
            solve_time = (time.time() - start) * 1000
        except Exception as e:
            logger.error(f"Z3 solver error: {e}")
            return {"status": "error", "solve_time_ms": 0, "error": str(e)}

        if result == sat:
            model = self.optimizer.model()
            solution = self._extract_solution(model)
            logger.info(f"Optimization solved in {solve_time:.0f}ms")
            return {
                "status": "optimal",
                "solve_time_ms": round(solve_time),
                "solution": solution,
            }
        else:
            logger.warning(f"No solution found ({result}) in {solve_time:.0f}ms")
            return {
                "status": "no_solution",
                "solve_time_ms": round(solve_time),
            }

    def _extract_solution(self, model) -> dict[str, Any]:
        """Extract meal plan from Z3 model."""
        recipes = self.problem.get("recipes", [])
        recipe_map = {r["id"]: r for r in recipes}
        days = self.problem.get("planning_horizon", {}).get("days", 7)
        start_date = self.problem.get("planning_horizon", {}).get("start_date", "")
        meal_types = self.problem.get("planning_horizon", {}).get("meal_types", ["dinner"])

        meal_plan = []
        selected_recipe_ids = []

        try:
            from datetime import date as dt_date, timedelta
            start = dt_date.fromisoformat(start_date) if start_date else None
        except (ValueError, TypeError):
            start = None

        for day in range(days):
            for rid in self.recipe_vars:
                key = (rid, day)
                if key in self.assign_vars and model.evaluate(self.assign_vars[key], model_completion=True):
                    if str(model.evaluate(self.assign_vars[key], model_completion=True)) == "True":
                        date_str = ""
                        if start:
                            date_str = (start + timedelta(days=day)).isoformat()

                        recipe_info = recipe_map.get(rid, {})
                        meal_plan.append({
                            "date": date_str,
                            "day_index": day,
                            "meal_type": meal_types[0] if meal_types else "dinner",
                            "recipe_id": rid,
                            "recipe_name": recipe_info.get("name", "Unknown"),
                        })
                        selected_recipe_ids.append(rid)

        # Shopping list
        shopping_list = []
        inventory = self.problem.get("inventory", [])
        inv_name_map = {item["ingredient_id"]: item.get("name", "Unknown") for item in inventory}

        # Also build name map from recipe ingredients
        for recipe in recipes:
            for ing in recipe.get("ingredients", []):
                if ing["ingredient_id"] not in inv_name_map:
                    inv_name_map[ing["ingredient_id"]] = ing.get("name", "Unknown")

        for iid, var in self.buy_vars.items():
            buy_qty = model.evaluate(var, model_completion=True)
            try:
                qty_int = buy_qty.as_long() if hasattr(buy_qty, 'as_long') else int(str(buy_qty))
            except (ValueError, AttributeError):
                qty_int = 0
            if qty_int > 0:
                shopping_list.append({
                    "ingredient_id": iid,
                    "name": inv_name_map.get(iid, "Unknown"),
                    "quantity": qty_int,
                })

        # Metrics
        expiring_used = 0
        total_expiring = 0
        for item in inventory:
            dte = item.get("days_until_expiry")
            if dte is not None and dte <= 7:
                total_expiring += 1
                # Check if any selected recipe uses this ingredient
                for rid in selected_recipe_ids:
                    recipe_info = recipe_map.get(rid, {})
                    for ing in recipe_info.get("ingredients", []):
                        if ing["ingredient_id"] == item["ingredient_id"]:
                            expiring_used += 1
                            break

        # Explanations
        explanations = []
        for entry in meal_plan:
            rid = entry["recipe_id"]
            recipe_info = recipe_map.get(rid, {})
            uses_expiring = []
            for ing in recipe_info.get("ingredients", []):
                for inv_item in inventory:
                    if inv_item["ingredient_id"] == ing["ingredient_id"]:
                        dte = inv_item.get("days_until_expiry")
                        if dte is not None and dte <= 7:
                            uses_expiring.append(inv_item.get("name", "item"))
            if uses_expiring:
                explanations.append(
                    f"Selected '{entry['recipe_name']}' for day {entry['day_index'] + 1} "
                    f"to use {', '.join(uses_expiring)} expiring soon"
                )

        return {
            "meal_plan": meal_plan,
            "shopping_list": shopping_list,
            "metrics": {
                "expiring_ingredients_used": expiring_used,
                "total_expiring_ingredients": total_expiring,
                "shopping_items_count": len(shopping_list),
                "variety_score": len(set(selected_recipe_ids)) / max(days, 1),
                "recipes_selected": len(selected_recipe_ids),
            },
            "explanation": explanations,
        }


def optimize_meal_plan(problem: dict[str, Any], timeout_ms: int = 5000) -> dict[str, Any]:
    """Convenience function to build and solve a meal plan optimization problem."""
    optimizer = MealPlanOptimizer(problem)
    optimizer.build_model()
    return optimizer.solve(timeout_ms=timeout_ms)


def quick_suggestions(
    inventory: list[dict],
    recipes: list[dict],
    mode: str = "use_expiring",
    limit: int = 5,
) -> list[dict[str, Any]]:
    """Lighter suggestion endpoint - scoring without full Z3 optimization.

    Scores recipes by expiring ingredient usage and availability.
    """
    # Build expiry urgency map
    expiry_map: dict[str, dict] = {}
    for item in inventory:
        iid = item["ingredient_id"]
        dte = item.get("days_until_expiry")
        if dte is not None and dte <= 7:
            expiry_map[iid] = item

    inv_map: dict[str, float] = {}
    for item in inventory:
        iid = item["ingredient_id"]
        inv_map[iid] = inv_map.get(iid, 0) + item.get("quantity", 0)

    suggestions = []
    for recipe in recipes:
        rid = recipe["id"]
        ingredients = recipe.get("ingredients", [])
        if not ingredients:
            continue

        expiring_used = []
        missing = []
        score = 0.0

        for ing in ingredients:
            iid = ing["ingredient_id"]
            if iid in expiry_map:
                exp_item = expiry_map[iid]
                dte = exp_item.get("days_until_expiry", 7)
                score += 1.0 / max(dte, 1)
                expiring_used.append(exp_item.get("name", "Unknown"))
            elif iid not in inv_map or inv_map[iid] < ing.get("quantity", 1):
                missing.append(ing.get("name", "Unknown"))

        if mode == "use_expiring" and not expiring_used:
            continue

        # Availability bonus
        available_count = sum(
            1 for ing in ingredients if ing["ingredient_id"] in inv_map
        )
        availability = available_count / len(ingredients) if ingredients else 0

        # Combined score
        final_score = score * 0.6 + availability * 0.3 - len(missing) * 0.1

        reason_parts = []
        if expiring_used:
            reason_parts.append(f"Uses {len(expiring_used)} expiring ingredient{'s' if len(expiring_used) != 1 else ''}")
        if missing:
            reason_parts.append(f"need {len(missing)} more item{'s' if len(missing) != 1 else ''}")
        else:
            reason_parts.append("all ingredients available")
        reason = " - ".join(reason_parts)

        suggestions.append({
            "recipe_id": rid,
            "recipe_name": recipe.get("name", "Unknown"),
            "score": round(final_score, 3),
            "expiring_used": expiring_used,
            "missing": missing,
            "reason": reason,
        })

    suggestions.sort(key=lambda s: (-s["score"], len(s["missing"])))
    return suggestions[:limit]
