# Ash Direct Usage Audit

This document tracks all instances where we're directly using `Ash.read`, `Ash.create`, `Ash.update`, `Ash.destroy`, etc. instead of using code interfaces defined on resources.

## Why This Matters

Using code interfaces instead of direct Ash calls provides:
- Better type safety and compile-time checks
- Clearer API boundaries
- Easier refactoring
- Better documentation through function signatures
- Reduced boilerplate

## Instances Found

### Context Modules (lib/grocery_planner)

#### ✅ lib/grocery_planner/checks/actor_member_of_account.ex
- **Line 14**: `Ash.exists?/2`
- **Reason**: Used in policy check - appropriate direct usage for low-level query
- **Action**: No change needed (policy checks are appropriate for direct Ash usage)

#### ❌ lib/grocery_planner/meal_planning/voting.ex

**Line 14**: `Ash.create/2`
```elixir
|> Ash.create(actor: actor, tenant: account_id)
```
- **Resource**: MealPlanVoteSession
- **Action**: `:start`
- **Recommendation**: Add code interface to MealPlanVoteSession

**Line 19**: `Ash.first/2`
```elixir
|> Ash.first(tenant: account_id)
```
- **Resource**: MealPlanVoteSession
- **Action**: Query for open session
- **Recommendation**: Add code interface method like `open_session/1`

**Line 31**: `Ash.create/2`
```elixir
|> Ash.create(actor: actor, tenant: account_id)
```
- **Resource**: MealPlanVoteEntry
- **Action**: `:vote`
- **Recommendation**: Add code interface to MealPlanVoteEntry

**Line 36**: `Ash.get/4`
```elixir
{:ok, session} <- Ash.get(MealPlanVoteSession, session_id, tenant: account_id, actor: actor)
```
- **Resource**: MealPlanVoteSession
- **Recommendation**: Add code interface `get/2`

**Line 52**: `Ash.read/2`
```elixir
|> Ash.read(actor: actor, tenant: account_id)
```
- **Resource**: MealPlanVoteEntry
- **Action**: List entries for session
- **Recommendation**: Add code interface `list_for_session/3`

**Line 69**: `Ash.update/2`
```elixir
|> Ash.update(actor: actor, tenant: account_id)
```
- **Resource**: MealPlanVoteSession
- **Action**: `:mark_processed`
- **Recommendation**: Add code interface to MealPlanVoteSession

**Line 99**: `Ash.create/2`
```elixir
|> Ash.create(actor: actor, tenant: account_id)
```
- **Resource**: MealPlan
- **Action**: `:create`
- **Recommendation**: Add code interface to MealPlan

### LiveView Modules (lib/grocery_planner_web)

#### ❌ lib/grocery_planner_web/live/voting_live.ex

**Line 114**: `Ash.read!/2`
```elixir
|> Ash.read!(actor: socket.assigns.current_user)
```
- **Resource**: Recipe
- **Action**: `:read` with filter for favorites
- **Recommendation**: Add code interface method `list_favorites/2`

**Line 133**: `Ash.read!/2`
```elixir
|> Ash.read!(actor: socket.assigns.current_user, tenant: account_id)
```
- **Resource**: MealPlanVoteEntry
- **Action**: Query entries for session
- **Recommendation**: Use code interface once added to Voting context

#### ❌ lib/grocery_planner_web/live/inventory_live.ex

**Line 1208**: `Ash.destroy/2` - GroceryItem
**Line 1246**: `Ash.destroy/2` - Category
**Line 1284**: `Ash.destroy/2` - StorageLocation
**Line 1436**: `Ash.destroy/2` - InventoryEntry
**Line 1483**: `Ash.read/2` - GroceryItem
**Line 1492**: `Ash.read/2` - InventoryEntry
- **Recommendation**: Add code interfaces to all Inventory resources

#### ❌ lib/grocery_planner_web/live/meal_planner_live.ex

**Line 87**: `Ash.read!/2` - Recipe
**Line 128**: `Ash.create/2` - MealPlan
**Line 149**: `Ash.get/3` - MealPlan
**Line 156**: `Ash.destroy/2` - MealPlan
**Line 178**: `Ash.get!/2` - MealPlan
**Line 213**: `Ash.update/2` - MealPlan
**Line 237**: `Ash.read!/2` - MealPlan
**Line 261**: `Ash.read!/2` - Recipe
- **Recommendation**: Add code interfaces to MealPlan and Recipe resources

#### ❌ lib/grocery_planner_web/live/recipe_show_live.ex

**Line 56**: `Ash.destroy/2` - Recipe
- **Recommendation**: Add code interface to Recipe resource

## Summary Statistics

### Total Direct Ash Calls
- **Context Modules**: 8 instances (1 acceptable, 7 need interfaces)
- **LiveView Modules**: 19 instances
- **Total**: 27 instances needing code interfaces

### Resources Needing Code Interfaces

1. **MealPlanVoteSession** (4 calls)
   - `start/2` - create with account_id
   - `get/2` - get by id with tenant
   - `open_session/1` - find open session for account
   - `mark_processed/3` - update session with winners

2. **MealPlanVoteEntry** (3 calls)
   - `vote/4` - cast a vote
   - `list_for_session/3` - list votes for session and account

3. **MealPlan** (7 calls)
   - `create/5` - create meal plan
   - `get/2` - get by id
   - `destroy/2` - delete meal plan
   - `update/2` - update meal plan
   - `list_for_date_range/3` - list meals in date range

4. **Recipe** (5 calls)
   - `list_favorites/2` - list favorite recipes
   - `list/2` - list recipes with filters
   - `destroy/2` - delete recipe

5. **GroceryItem** (3 calls)
   - `destroy/2` - delete item
   - `list/2` - list items with filters

6. **Category** (1 call)
   - `destroy/2` - delete category

7. **StorageLocation** (1 call)
   - `destroy/2` - delete location

8. **InventoryEntry** (3 calls)
   - `destroy/2` - delete entry
   - `list/2` - list entries with filters

## Recommended Action Plan

### Phase 1: Voting Feature (High Priority)
Since the voting feature was just completed, add code interfaces to:
1. MealPlanVoteSession
2. MealPlanVoteEntry
3. Update Voting context module to use interfaces
4. Update VotingLive to use interfaces

### Phase 2: Meal Planning
1. Add code interfaces to MealPlan
2. Update MealPlannerLive to use interfaces

### Phase 3: Recipes
1. Add code interfaces to Recipe
2. Update RecipeShowLive to use interfaces

### Phase 4: Inventory
1. Add code interfaces to all Inventory resources
2. Update InventoryLive to use interfaces

## Example Code Interface Addition

For MealPlanVoteSession:

```elixir
# In resource definition
code_interface do
  define :start, args: [:account_id]
  define :get, args: [:id]
  define :open_session, args: [:account_id], action: :read
  define :mark_processed, args: [:winning_recipe_ids]
end
```

Then in Voting context:

```elixir
def start_vote(account_id, actor) do
  MealPlanVoteSession.start(account_id, actor: actor, tenant: account_id)
end

def open_session(account_id) do
  MealPlanVoteSession.open_session(account_id, tenant: account_id)
end
```

## Notes

- Policy checks using `Ash.exists?` are acceptable for direct usage
- Some complex queries may still benefit from direct Ash usage
- Code interfaces can be added incrementally without breaking existing functionality
- All direct calls should eventually migrate to code interfaces for consistency
