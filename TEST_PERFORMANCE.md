# Test Performance Tracking

## Goals
- Reduce total test suite time to under 10 seconds (currently ~20s+).
- Eliminate tests taking > 500ms.
- Ensure 100% pass rate.

## Baseline (2025-12-15)
- **Total Tests:** 258
- **Failures:** 0
- **Total Time:** ~25s

### Slowest Tests (Top 5)
1. `GroceryPlanner.Inventory.GroceryItemTagTest`: grocery_item_tag listing does not list tags from other accounts (~1111ms)
2. `GroceryPlannerWeb.AnalyticsLiveTest`: renders dashboard with empty state (~1103ms)
3. `GroceryPlannerWeb.ErrorHTMLTest`: renders 404.html (~1070ms)
4. `GroceryPlannerWeb.InventoryLiveTest`: multi-tenancy only shows items from current account (~1070ms)
5. `GroceryPlanner.Recipes.RecipeAuthorizationTest`: denies user from creating recipe in account they're not a member of (~1010ms)

## Action Plan
1.  **Fix Failures:** Resolve the 2 failures in `test/grocery_planner_web/live/analytics_live_test.exs`.
2.  **Optimize `InventoryLiveTest`:** Investigate why multi-tenancy tests are so slow. Likely due to setup overhead or database contention.
3.  **Optimize `AuthControllerTest`:** Password hashing (Bcrypt) is intentionally slow. Configure Bcrypt to be faster in `:test` environment.
4.  **Parallelization:** Ensure tests are running async where possible (`use GroceryPlannerWeb.ConnCase, async: true`).

## Current Status (2025-12-15)
- **Total Tests:** 258
- **Failures:** 0
- **Total Time:** ~14.5s (ExUnit), 0.00s Sync
- **Slowest Tests:** All < 200ms

### Top 5 Slowest
1. `GroceryPlannerWeb.InventoryLiveTest`: deletes inventory entry (~178ms)
2. `GroceryPlannerWeb.ShoppingLiveTest`: adds item to list (~175ms)
3. `GroceryPlannerWeb.InventoryLiveWasteTest`: consume entry creates usage log (~174ms)
4. `GroceryPlannerWeb.InventoryLiveTest`: creates new inventory entry (~173ms)
5. `GroceryPlannerWeb.VotingLiveTest`: finalizing votes creates meal plans (~166ms)

## Log
- **2025-12-15:** Created baseline. Identified 2 failures and slow auth/inventory tests.
- **2025-12-15:** Enabled `async: true` for all tests. Reduced slowest tests to ~180ms. Total ExUnit time reduced to ~14.5s. Sync time 0.00s.
