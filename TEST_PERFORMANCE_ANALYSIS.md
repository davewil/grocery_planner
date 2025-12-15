# Test Performance Analysis

**Analysis Date:** 2025-12-13
**Current Test Suite Performance:** 120.6 seconds (255 tests)

## Executive Summary

The test suite has significant performance optimization opportunities. Tests are currently running predominantly in synchronous mode (111.2s sync vs 9.3s async), representing a **12x performance difference**. With proper async configuration and setup optimization, the test suite could potentially run in **under 20 seconds** instead of 2+ minutes.

## Current Metrics

- **Total Tests:** 255
- **Total Time:** 120.6 seconds (2:07 real time)
- **Async Tests:** 9.3 seconds
- **Sync Tests:** 111.2 seconds
- **Test Files:** 36 total
- **Async-enabled Files:** 7 (19.4%)
- **Sync-only Files:** 29 (80.6%)

## Critical Issues

### 1. Ash Framework Async Disabled Globally ⚠️ HIGH IMPACT

**Location:** `config/test.exs:2`

```elixir
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true
```

**Impact:** This global configuration disables async operations in Ash, which may limit the effectiveness of `async: true` in individual test files.

**Recommendation:**
- Investigate if `disable_async?: true` is still necessary
- If policy breakdowns are only needed for debugging, consider removing or making conditional
- This single change could unlock massive performance gains

### 2. Low Async Adoption Rate

**Current State:**
Only 7 out of 36 test files use `async: true`:

```
✓ test/grocery_planner_web/controllers/error_json_test.exs
✓ test/grocery_planner_web/controllers/error_html_test.exs
✓ test/grocery_planner/external/external_recipe_test.exs
✓ test/grocery_planner/external/the_meal_db_test.exs
✓ test/grocery_planner/recipes/recipe_authorization_test.exs
✓ test/grocery_planner/recipes/recipe_calculations_test.exs
✓ test/grocery_planner/recipes/recipe_favorite_test.exs
```

**Missing Async (29 files):**
All other test files run synchronously despite being good candidates for async mode:
- `test/grocery_planner/inventory/*_test.exs` (6 files)
- `test/grocery_planner/meal_planning/*_test.exs` (2 files)
- `test/grocery_planner/notifications/*_test.exs` (3 files)
- `test/grocery_planner/shopping/*_test.exs` (2 files)
- `test/grocery_planner/analytics/*_test.exs` (1 file)
- `test/grocery_planner_web/live/*_test.exs` (10 files)
- And others...

**Recommendation:**
Enable `async: true` for all tests that don't:
- Share global state
- Use external services (unless mocked)
- Depend on specific database sequences

Most DataCase and ConnCase tests should be async-safe due to the sandbox.

### 3. Repetitive Setup Code

**Metrics:**
- 81 `describe` blocks
- 56 uses of `create_account_and_user()`
- 36 test module-level `setup` blocks
- Each setup creates fresh account + user + membership (3 DB writes minimum)

**Example Pattern (repeated across many files):**

```elixir
# In grocery_item_test.exs
describe "create/1" do
  setup do
    account = create_account()
    user = create_user(account)
    category = create_category(account, user, %{name: "Dairy"})
    %{account: account, user: user, category: category}
  end
  # ... tests
end

describe "read/0" do
  setup do
    account = create_account()
    user = create_user(account)
    %{account: account, user: user}
  end
  # ... tests
end
```

**Impact:**
- 56+ accounts created per test run
- 56+ users created per test run
- 56+ account memberships created per test run
- Minimum 168+ database writes just for basic setup
- These run sequentially in sync tests

**Recommendation:**
- Move common setup to module-level `setup` blocks (outside `describe`)
- Use `setup_all` for read-only test fixtures when async is enabled
- Consider test data builders/factories for complex scenarios

### 4. Database Configuration

**Current Config (test.exs:14-16):**
```elixir
pool: Ecto.Adapters.SQL.Sandbox,
pool_size: System.schedulers_online() * 2,
```

**Analysis:**
- Pool size is appropriate for parallel tests
- Sandbox is correctly configured in DataCase
- `shared: not tags[:async]` pattern is correct

**Recommendation:**
- Pool size is fine (likely 16-32 connections on modern systems)
- Consider increasing if async tests are enabled across the board

## Performance Opportunities by Category

### Immediate Wins (Estimated 60-80% improvement)

1. **Remove `disable_async?: true` from Ash config** (if possible)
   - Test impact first
   - May require policy debugging alternative approach

2. **Enable async on low-hanging fruit** (20 files)
   - All controller tests (currently only 2/3 are async)
   - All external service tests (already done)
   - Recipe tests (already done)
   - Analytics tests
   - Simple CRUD resource tests (inventory, categories, storage locations)

### Medium-term Improvements (Estimated additional 10-20% improvement)

3. **Refactor setup blocks**
   - Consolidate repeated account/user creation
   - Use module-level setup where possible
   - Extract common patterns to test helpers

4. **Optimize test data creation**
   - Reduce unnecessary attributes in test factories
   - Use `build` instead of `create` where database persistence isn't needed
   - Batch insert operations where possible

### Advanced Optimizations (Estimated additional 5-10% improvement)

5. **Partitioned testing**
   - Leverage `MIX_TEST_PARTITION` (already supported in config)
   - Run tests in parallel across multiple database partitions in CI

6. **Strategic use of `setup_all`**
   - For read-only test data in async tests
   - Reduces per-test setup overhead

## Files Requiring Async Analysis

These files should be evaluated for async compatibility:

### High Priority (Pure CRUD, likely async-safe)
- `test/grocery_planner/inventory/category_test.exs`
- `test/grocery_planner/inventory/storage_location_test.exs`
- `test/grocery_planner/inventory/grocery_item_test.exs`
- `test/grocery_planner/inventory/inventory_entry_test.exs`
- `test/grocery_planner/inventory/grocery_item_tag_test.exs`
- `test/grocery_planner/analytics/usage_log_test.exs`

### Medium Priority (May have shared state)
- `test/grocery_planner/shopping_test.exs`
- `test/grocery_planner/shopping/logic_test.exs`
- `test/grocery_planner/meal_planning/meal_plan_test.exs`
- `test/grocery_planner/meal_planning/meal_plan_templates_test.exs`
- `test/grocery_planner/notifications/expiration_alerts_test.exs`
- `test/grocery_planner/notifications/notification_preference_test.exs`
- `test/grocery_planner/notifications/recipe_suggestions_test.exs`

### Lower Priority (LiveView/Integration tests - verify no JS/external dependencies)
- `test/grocery_planner_web/live/inventory_live_test.exs`
- `test/grocery_planner_web/live/inventory_live_waste_test.exs`
- `test/grocery_planner_web/live/analytics_live_test.exs`
- `test/grocery_planner_web/live/meal_planner_live_test.exs`
- `test/grocery_planner_web/live/recipe_search_live_test.exs`
- `test/grocery_planner_web/live/recipes_live_test.exs`
- `test/grocery_planner_web/live/shopping_live_test.exs`
- `test/grocery_planner_web/live/dashboard_live_test.exs`
- `test/grocery_planner_web/live/settings_live_test.exs`
- `test/grocery_planner_web/live/voting_live_test.exs`

## Implementation Strategy

### Phase 1: Investigate Async Config
1. Research why `disable_async?: true` is set in Ash config
2. Test removing it in dev environment
3. Verify all tests still pass
4. If policy debugging needed, find alternative approach

### Phase 2: Quick Wins
1. Enable async on all controller tests (1 file remaining)
2. Enable async on all pure resource tests (6 inventory files)
3. Enable async on analytics, shopping, meal planning, notifications (9 files)
4. Run full suite and measure improvement

### Phase 3: Setup Optimization
1. Audit all test files for repeated setup blocks
2. Consolidate account/user creation to module level
3. Consider `setup_all` for read-only fixtures in async tests
4. Measure improvement

### Phase 4: LiveView Tests
1. Carefully evaluate each LiveView test for async safety
2. Enable async where safe (no shared JS/browser state)
3. May need to remain sync if they interact with global state

### Phase 5: Monitoring
1. Add test timing to CI
2. Set performance budgets (e.g., "full suite under 30 seconds")
3. Flag new tests that don't use async appropriately

## Expected Outcomes

**Conservative Estimate:**
- Phase 1 + 2: 60-80 seconds (50% improvement)
- Phase 3: 45-60 seconds (63% improvement)
- Phase 4: 30-45 seconds (75% improvement)

**Optimistic Estimate:**
- With all optimizations: 15-25 seconds (80-90% improvement)
- Most of the runtime would be actual test execution, not setup

## Testing Best Practices Going Forward

1. **Default to async:** New tests should use `async: true` unless proven unsafe
2. **Shared setup:** Use module-level setup for common fixtures
3. **Minimal setup:** Only create data required for the specific test
4. **Document sync:** If a test must be sync, add a comment explaining why
5. **CI monitoring:** Track test performance over time

## Warnings and Considerations

1. **Ash async flag:** The `disable_async?: true` setting may be critical for policy evaluation. Investigate thoroughly before removing.

2. **Race conditions:** Enabling async may expose race conditions in application code. This is actually good - it reveals real bugs.

3. **Shared external resources:** Tests using external APIs, file system, or other shared resources may need to remain synchronous or use proper locking.

4. **Test partition support:** The codebase already supports `MIX_TEST_PARTITION` for CI parallelization, which is excellent for further scaling.

5. **Flaky tests:** When enabling async, watch for intermittent failures. These usually indicate improper test isolation or shared state.

## Additional Observations

### Positive Aspects
- ✓ Sandbox mode properly configured
- ✓ Database pool sized appropriately
- ✓ Test helpers are well-organized (`InventoryTestHelpers`)
- ✓ Partition support already in place for CI scaling
- ✓ Some tests already using async correctly (recipes, external)

### Areas for Improvement
- ⚠ Policy debugging may be hurting performance (`show_policy_breakdowns?: true`)
- ⚠ No test timing metrics in output (consider adding)
- ⚠ High setup duplication across test files
- ⚠ Some unused variables in tests (warnings shown in output)

## Conclusion

The test suite has excellent fundamentals but is held back by conservative async settings and repetitive setup patterns. With targeted optimizations, particularly around the Ash async configuration and enabling async mode on appropriate tests, the suite could run **4-6x faster**. This would dramatically improve developer experience and CI pipeline efficiency.

The highest-impact change is investigating the `disable_async?: true` setting in the Ash configuration, as this single flag may be preventing full async performance benefits.
