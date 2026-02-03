# API-001: Mobile Client API Enhancement

## Overview

**Feature:** DDD Aggregate Root Pattern for Mobile-Ready JSON:API with Offline Sync
**Priority:** High
**Epic:** Mobile App Support
**Status:** Proposed

## Design Decisions (Confirmed)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Mobile Client Status | Future planning | No existing mobile client - building for future |
| Backward Compatibility | Breaking changes OK | App not publicly available yet |
| Offline Support | Full offline read/write | Users need to check items off shopping lists without signal |
| Custom Actions | Include all | Expose generate_from_meal_plans, complete, toggle_check |
| Aggregate Scope | All four together | ShoppingList, Recipe, GroceryItem, MealPlan |
| Implementation Priority | Simultaneous | Implement all aggregates in parallel |

## Problem Statement

The current JSON:API implementation is incomplete for mobile client consumption. While `AshJsonApi` is configured and several resources are exposed, critical child entities required for core mobile workflows are either missing or improperly structured.

**Current State Analysis:**

| Resource | API Status | Issue |
|----------|-----------|-------|
| `InventoryEntry` | Exposed at `/inventory_entries` | Flat endpoint, not nested under aggregate root |
| `ShoppingListItem` | **Not Exposed** | No `json_api` block - mobile cannot manage list items |
| `RecipeIngredient` | **Not Exposed** | No `json_api` block - mobile cannot manage ingredients |
| `MealPlanTemplate` | **Not Exposed** | No `json_api` block - mobile cannot manage templates |
| `MealPlanTemplateEntry` | **Not Exposed** | No `json_api` block - mobile cannot manage template entries |
| `MealPlanVoteSession` | **Not Exposed** | No `json_api` block - mobile cannot create vote sessions |
| `MealPlanVoteEntry` | **Not Exposed** | No `json_api` block - mobile cannot cast votes |

**Impact on Mobile Clients:**

1. Cannot add/edit/remove items from shopping lists via API
2. Cannot manage recipe ingredients via API
3. Cannot fetch inventory entries scoped to a specific grocery item
4. Cannot manage meal plan templates or participate in meal voting
5. No clear aggregate boundaries for offline sync strategies
6. No infrastructure for incremental sync (updated_at filtering, soft deletes)

## Design Philosophy

This spec adopts the **DDD Aggregate Root** pattern recommended in `IMPLEMENTATION_PLAN.md` (lines 826-833):

> *"Define aggregate roots and expose child entities only via parent relationships (e.g., `/api/json/grocery_items/:id/inventory_entries`). This would enforce data consistency boundaries..."*

### Aggregate Root Boundaries

```
GroceryItem (Aggregate Root)
└── InventoryEntry (Child Entity)

ShoppingList (Aggregate Root)
└── ShoppingListItem (Child Entity)

Recipe (Aggregate Root)
└── RecipeIngredient (Child Entity)

MealPlan (Aggregate Root)
├── MealPlanTemplate (Child Entity)
│   └── MealPlanTemplateEntry (Grandchild Entity)
└── MealPlanVoteSession (Child Entity)
    └── MealPlanVoteEntry (Grandchild Entity)
```

**Benefits:**
- Clear ownership and lifecycle management
- Simplified mobile sync (fetch aggregate + children atomically)
- Consistent authorization (inherit from parent)
- Better caching strategies (invalidate by aggregate)
- Offline-first architecture with conflict resolution boundaries

## User Stories

### US-001: Manage Shopping List Items via API ✅ IMPLEMENTED
**As a** mobile app user
**I want** to add, edit, check, and remove items from my shopping list via API
**So that** I can manage my shopping list from my phone

**Acceptance Criteria:**
- [x] `GET /shopping_lists/:id/items` returns all items in a list
- [x] `POST /shopping_lists/:id/items` adds a new item to the list
- [x] `PATCH /shopping_lists/:id/items/:item_id` updates an item
- [x] `PATCH /shopping_lists/:id/items/:item_id/check` toggles item checked state
- [x] `DELETE /shopping_lists/:id/items/:item_id` removes an item
- [x] All operations respect tenant isolation via `account_id`

**Implementation Notes (2026-02-03):**
- Added AshJsonApi.Resource extension to ShoppingListItem
- Created nested routes under `/shopping_lists/:shopping_list_id/items`
- Added `create_from_api` action that derives `account_id` from parent shopping list
- Custom routes for `/check`, `/uncheck`, `/toggle` actions
- 14 behavioral tests covering all CRUD operations and tenant isolation

### US-002: Manage Recipe Ingredients via API ✅ IMPLEMENTED
**As a** mobile app user
**I want** to view and manage recipe ingredients via API
**So that** I can customize recipes from my phone

**Acceptance Criteria:**
- [x] `GET /recipes/:id/ingredients` returns all ingredients for a recipe
- [x] `POST /recipes/:id/ingredients` adds an ingredient to a recipe
- [x] `PATCH /recipes/:id/ingredients/:ingredient_id` updates an ingredient
- [x] `DELETE /recipes/:id/ingredients/:ingredient_id` removes an ingredient
- [x] Ingredients include linked `grocery_item` data when loaded

**Implementation Notes (2026-02-03):**
- Added AshJsonApi.Resource extension to RecipeIngredient
- Created nested routes under `/recipes/:recipe_id/ingredients`
- Added `create_from_api` action that derives `account_id` from parent recipe
- 9 behavioral tests covering all CRUD operations and tenant isolation

### US-003: Query Inventory by Grocery Item ✅ IMPLEMENTED
**As a** mobile app user
**I want** to see all inventory entries for a specific grocery item
**So that** I can track quantities across storage locations

**Acceptance Criteria:**
- [x] `GET /grocery_items/:id/inventory_entries` returns entries for that item
- [x] `POST /grocery_items/:id/inventory_entries` creates entry for that item
- [x] `PATCH /grocery_items/:id/inventory_entries/:entry_id` updates entry
- [x] `DELETE /grocery_items/:id/inventory_entries/:entry_id` removes entry
- [x] Supports filtering by status (available, expired, consumed)
- [x] All operations respect tenant isolation via `account_id`

**Implementation Notes (2026-02-03):**
- Changed InventoryEntry from flat `/inventory_entries` to nested `/grocery_items/:grocery_item_id/inventory_entries`
- Created `list_by_grocery_item` read action with explicit filter (derive_filter didn't work reliably)
- Created `create_from_api` action that derives `account_id` from parent grocery item
- Fixed create policy to use `authorize_if always()` (relationship filters don't work for creates)
- Made `belongs_to :grocery_item` public for filtering
- 11 behavioral tests covering all CRUD operations and tenant isolation

### US-004: Atomic Operations with Side Effects
**As a** mobile app user
**I want** custom actions exposed via API for complex operations
**So that** I can perform multi-step workflows in a single request

**Acceptance Criteria:**
- [ ] `POST /shopping_lists/:id/actions/generate_from_meal_plans` available
- [ ] `POST /shopping_lists/:id/items/:item_id/actions/add_to_inventory` available
- [ ] `POST /meal_plans/:id/actions/complete` marks meal complete
- [ ] Action responses include updated resource state

### US-005: Consistent Error Responses
**As a** mobile app developer
**I want** consistent JSON:API error responses
**So that** I can handle errors predictably

**Acceptance Criteria:**
- [ ] All errors follow JSON:API error format
- [ ] Validation errors include field-level details
- [ ] Authorization failures return 403 with descriptive message
- [ ] Not found errors return 404 with resource type

### US-006: Manage Meal Plan Templates via API
**As a** mobile app user
**I want** to create and manage meal plan templates via API
**So that** I can set up weekly meal patterns from my phone

**Acceptance Criteria:**
- [ ] `GET /meal_plans/templates` returns all templates for account
- [ ] `POST /meal_plans/templates` creates a new template
- [ ] `GET /meal_plans/templates/:id/entries` returns template entries
- [ ] `POST /meal_plans/templates/:id/entries` adds an entry to template
- [ ] `POST /meal_plans/templates/:id/apply` creates meal plans from template

### US-007: Participate in Meal Plan Voting via API
**As a** household member
**I want** to vote on meal options via API
**So that** I can participate in meal planning from my phone

**Acceptance Criteria:**
- [ ] `GET /meal_plans/vote_sessions` returns active vote sessions
- [ ] `POST /meal_plans/vote_sessions` creates a new vote session
- [ ] `GET /meal_plans/vote_sessions/:id/entries` returns vote entries
- [ ] `POST /meal_plans/vote_sessions/:id/entries` casts a vote
- [ ] `POST /meal_plans/vote_sessions/:id/close` closes voting and selects winner

### US-008: Offline Sync Support
**As a** mobile app user
**I want** to sync changes made offline when I regain connectivity
**So that** I can use the app in areas with poor signal (like grocery stores)

**Acceptance Criteria:**
- [ ] All resources include `updated_at` in responses
- [ ] `GET` endpoints support `?filter[updated_at][gte]=timestamp` parameter
- [ ] Deleted resources use soft delete with `deleted_at` timestamp
- [ ] `GET` endpoints support `?filter[include_deleted]=true` for sync
- [ ] Responses include sync metadata (server timestamp, has_more flag)
- [ ] Conflict detection via `If-Unmodified-Since` header support

### US-009: Bulk Operations for Sync Efficiency
**As a** mobile app
**I want** to submit multiple changes in a single request
**So that** I can sync efficiently when reconnecting

**Acceptance Criteria:**
- [ ] `POST /sync/batch` accepts array of operations
- [ ] Supports mixed create/update/delete operations
- [ ] Returns per-operation success/failure status
- [ ] Atomic option available (all-or-nothing)
- [ ] Conflict resolution strategy documented

## Technical Specification

### Route Structure

#### Current (Flat) Routes
```
GET    /api/json/inventory_entries
POST   /api/json/inventory_entries
PATCH  /api/json/inventory_entries/:id
DELETE /api/json/inventory_entries/:id
```

#### Proposed (DDD Aggregate) Routes

**ShoppingList Aggregate:**
```
GET    /api/json/shopping_lists
POST   /api/json/shopping_lists
GET    /api/json/shopping_lists/:id
PATCH  /api/json/shopping_lists/:id
DELETE /api/json/shopping_lists/:id

# Child entity routes (NEW)
GET    /api/json/shopping_lists/:id/items
POST   /api/json/shopping_lists/:id/items
GET    /api/json/shopping_lists/:id/items/:item_id
PATCH  /api/json/shopping_lists/:id/items/:item_id
DELETE /api/json/shopping_lists/:id/items/:item_id

# Custom actions (NEW)
POST   /api/json/shopping_lists/:id/complete
POST   /api/json/shopping_lists/:id/generate_from_meal_plans
```

**Recipe Aggregate:**
```
GET    /api/json/recipes
POST   /api/json/recipes
GET    /api/json/recipes/:id
PATCH  /api/json/recipes/:id
DELETE /api/json/recipes/:id

# Child entity routes (NEW)
GET    /api/json/recipes/:id/ingredients
POST   /api/json/recipes/:id/ingredients
GET    /api/json/recipes/:id/ingredients/:ingredient_id
PATCH  /api/json/recipes/:id/ingredients/:ingredient_id
DELETE /api/json/recipes/:id/ingredients/:ingredient_id
```

**GroceryItem Aggregate:**
```
GET    /api/json/grocery_items
POST   /api/json/grocery_items
GET    /api/json/grocery_items/:id
PATCH  /api/json/grocery_items/:id
DELETE /api/json/grocery_items/:id

# Child entity routes (NEW - replaces top-level)
GET    /api/json/grocery_items/:id/inventory_entries
POST   /api/json/grocery_items/:id/inventory_entries
GET    /api/json/grocery_items/:id/inventory_entries/:entry_id
PATCH  /api/json/grocery_items/:id/inventory_entries/:entry_id
DELETE /api/json/grocery_items/:id/inventory_entries/:entry_id
```

**MealPlan Aggregate:**
```
GET    /api/json/meal_plans
POST   /api/json/meal_plans
GET    /api/json/meal_plans/:id
PATCH  /api/json/meal_plans/:id
DELETE /api/json/meal_plans/:id

# Custom actions
POST   /api/json/meal_plans/:id/complete
POST   /api/json/meal_plans/:id/skip

# Templates (NEW)
GET    /api/json/meal_plans/templates
POST   /api/json/meal_plans/templates
GET    /api/json/meal_plans/templates/:id
PATCH  /api/json/meal_plans/templates/:id
DELETE /api/json/meal_plans/templates/:id
POST   /api/json/meal_plans/templates/:id/apply

# Template entries (NEW)
GET    /api/json/meal_plans/templates/:template_id/entries
POST   /api/json/meal_plans/templates/:template_id/entries
PATCH  /api/json/meal_plans/templates/:template_id/entries/:entry_id
DELETE /api/json/meal_plans/templates/:template_id/entries/:entry_id

# Vote sessions (NEW)
GET    /api/json/meal_plans/vote_sessions
POST   /api/json/meal_plans/vote_sessions
GET    /api/json/meal_plans/vote_sessions/:id
POST   /api/json/meal_plans/vote_sessions/:id/close

# Vote entries (NEW)
GET    /api/json/meal_plans/vote_sessions/:session_id/entries
POST   /api/json/meal_plans/vote_sessions/:session_id/entries
```

**Sync Infrastructure (NEW):**
```
# Bulk sync endpoint
POST   /api/json/sync/batch

# Sync metadata endpoint
GET    /api/json/sync/status
```

### Implementation Changes

#### 1. ShoppingListItem - Add JSON:API Support

```elixir
# lib/grocery_planner/shopping/shopping_list_item.ex

defmodule GroceryPlanner.Shopping.ShoppingListItem do
  use Ash.Resource,
    domain: GroceryPlanner.Shopping,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]  # ADD THIS

  json_api do
    type "shopping_list_item"

    routes do
      # Nested under ShoppingList aggregate root
      base("/shopping_lists/:shopping_list_id/items")

      index :read
      get :read
      post :create
      patch :update
      delete :destroy

      # Custom action routes
      patch :check, route: "/:id/check"
      patch :uncheck, route: "/:id/uncheck"
      patch :toggle_check, route: "/:id/toggle"
    end
  end

  # ... rest of resource
end
```

#### 2. RecipeIngredient - Add JSON:API Support

```elixir
# lib/grocery_planner/recipes/recipe_ingredient.ex

defmodule GroceryPlanner.Recipes.RecipeIngredient do
  use Ash.Resource,
    domain: GroceryPlanner.Recipes,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]  # ADD THIS

  json_api do
    type "recipe_ingredient"

    routes do
      # Nested under Recipe aggregate root
      base("/recipes/:recipe_id/ingredients")

      index :read
      get :read
      post :create
      patch :update
      delete :destroy
    end
  end

  # ... rest of resource
end
```

#### 3. InventoryEntry - Change to Nested Route

```elixir
# lib/grocery_planner/inventory/inventory_entry.ex

defmodule GroceryPlanner.Inventory.InventoryEntry do
  # ... existing config ...

  json_api do
    type "inventory_entry"

    routes do
      # CHANGE: Nested under GroceryItem aggregate root
      base("/grocery_items/:grocery_item_id/inventory_entries")

      index :read
      get :read
      post :create
      patch :update
      delete :destroy
    end
  end

  # ... rest of resource
end
```

#### 4. Parent Resources - Add Related Routes

```elixir
# lib/grocery_planner/shopping/shopping_list.ex

json_api do
  type "shopping_list"

  routes do
    base("/shopping_lists")
    get(:read)
    index :read
    post(:create)
    patch(:update)
    delete(:destroy)

    # ADD: Related routes for child entities
    related :items, :read

    # ADD: Custom action routes
    post :complete, route: "/:id/complete"
    post :generate_from_meal_plans, route: "/:id/generate"
  end
end
```

### 5. Offline Sync Infrastructure

#### Soft Deletes Migration

All syncable resources need a `deleted_at` column:

```elixir
defmodule GroceryPlanner.Repo.Migrations.AddSoftDeletesForSync do
  use Ecto.Migration

  def change do
    tables = [
      :shopping_list_items,
      :shopping_lists,
      :recipe_ingredients,
      :recipes,
      :inventory_entries,
      :grocery_items,
      :meal_plans,
      :meal_plan_templates,
      :meal_plan_template_entries,
      :meal_plan_vote_sessions,
      :meal_plan_vote_entries
    ]

    for table <- tables do
      alter table(table) do
        add :deleted_at, :utc_datetime, null: true
      end

      create index(table, [:deleted_at])
      create index(table, [:updated_at])
    end
  end
end
```

#### Sync-Aware Read Actions

```elixir
# Add to each syncable resource
read :sync do
  argument :since, :utc_datetime
  argument :include_deleted, :boolean, default: false

  filter expr(
    if is_nil(^arg(:since)) do
      true
    else
      updated_at >= ^arg(:since) or
        (not is_nil(deleted_at) and deleted_at >= ^arg(:since))
    end
  )

  filter expr(
    if ^arg(:include_deleted) do
      true
    else
      is_nil(deleted_at)
    end
  )

  prepare build(sort: [updated_at: :asc])
end
```

#### Batch Sync Controller

```elixir
defmodule GroceryPlannerWeb.Api.SyncController do
  use GroceryPlannerWeb, :controller

  @doc """
  Accepts batch of operations for offline sync.

  Request:
  {
    "operations": [
      {"op": "create", "type": "shopping_list_item", "data": {...}},
      {"op": "update", "type": "shopping_list_item", "id": "...", "data": {...}},
      {"op": "delete", "type": "shopping_list_item", "id": "..."}
    ],
    "atomic": false
  }
  """
  def batch(conn, params) do
    # Implementation handles each operation and returns per-op results
  end

  @doc """
  Returns sync status including server timestamp.
  """
  def status(conn, _params) do
    json(conn, %{
      server_time: DateTime.utc_now(),
      api_version: "1.0"
    })
  end
end
```

### Backward Compatibility Strategy

**Decision: Breaking Changes Allowed**

Since the app is not publicly available yet, we will:
1. Remove existing `/inventory_entries` flat endpoint immediately
2. Implement all new nested routes
3. Document changes in changelog
4. No deprecation period needed

### Authentication & Authorization

All nested routes inherit authorization from the parent aggregate:

```elixir
# Child resources verify parent ownership
policies do
  policy action_type(:read) do
    # Verify user has access to parent ShoppingList
    authorize_if relates_to_actor_via([:shopping_list, :account, :memberships, :user])
  end

  policy action_type([:create, :update, :destroy]) do
    authorize_if relates_to_actor_via([:shopping_list, :account, :memberships, :user])
  end
end
```

### Response Examples

#### GET /api/json/shopping_lists/:id/items

```json
{
  "data": [
    {
      "type": "shopping_list_item",
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "attributes": {
        "name": "Organic Milk",
        "quantity": "2",
        "unit": "gallons",
        "checked": false,
        "notes": null
      },
      "relationships": {
        "shopping_list": {
          "data": { "type": "shopping_list", "id": "550e8400-e29b-41d4-a716-446655440000" }
        },
        "grocery_item": {
          "data": { "type": "grocery_item", "id": "660e8400-e29b-41d4-a716-446655440002" }
        }
      }
    }
  ],
  "links": {
    "self": "/api/json/shopping_lists/550e8400-e29b-41d4-a716-446655440000/items"
  }
}
```

#### POST /api/json/shopping_lists/:id/items

**Request:**
```json
{
  "data": {
    "type": "shopping_list_item",
    "attributes": {
      "name": "Bread",
      "quantity": "1",
      "unit": "loaf"
    },
    "relationships": {
      "grocery_item": {
        "data": { "type": "grocery_item", "id": "optional-grocery-item-id" }
      }
    }
  }
}
```

**Response:**
```json
{
  "data": {
    "type": "shopping_list_item",
    "id": "newly-generated-uuid",
    "attributes": {
      "name": "Bread",
      "quantity": "1",
      "unit": "loaf",
      "checked": false
    }
  }
}
```

#### Error Response (Validation)

```json
{
  "errors": [
    {
      "status": "422",
      "source": { "pointer": "/data/attributes/name" },
      "title": "Invalid Attribute",
      "detail": "Name is required"
    }
  ]
}
```

## Testing Strategy

### Unit Tests

```elixir
defmodule GroceryPlannerWeb.Api.ShoppingListItemTest do
  use GroceryPlannerWeb.ConnCase
  import GroceryPlanner.Factory

  setup %{conn: conn} do
    user = insert(:user)
    account = insert(:account)
    insert(:account_membership, user: user, account: account)
    shopping_list = insert(:shopping_list, account: account)

    token = Phoenix.Token.sign(GroceryPlannerWeb.Endpoint, "api_auth", user.id)
    conn = put_req_header(conn, "authorization", "Bearer #{token}")

    {:ok, conn: conn, user: user, account: account, shopping_list: shopping_list}
  end

  describe "GET /api/json/shopping_lists/:id/items" do
    test "returns items for the shopping list", %{conn: conn, shopping_list: list} do
      item = insert(:shopping_list_item, shopping_list: list)

      conn = get(conn, "/api/json/shopping_lists/#{list.id}/items")

      assert %{"data" => [%{"id" => id}]} = json_response(conn, 200)
      assert id == item.id
    end

    test "returns 404 for non-existent list", %{conn: conn} do
      conn = get(conn, "/api/json/shopping_lists/#{Ecto.UUID.generate()}/items")
      assert json_response(conn, 404)
    end

    test "returns 403 for unauthorized list", %{conn: conn} do
      other_account = insert(:account)
      other_list = insert(:shopping_list, account: other_account)

      conn = get(conn, "/api/json/shopping_lists/#{other_list.id}/items")
      assert json_response(conn, 403)
    end
  end

  describe "POST /api/json/shopping_lists/:id/items" do
    test "creates a new item", %{conn: conn, shopping_list: list} do
      payload = %{
        "data" => %{
          "type" => "shopping_list_item",
          "attributes" => %{
            "name" => "Test Item",
            "quantity" => "1"
          }
        }
      }

      conn = post(conn, "/api/json/shopping_lists/#{list.id}/items", payload)

      assert %{"data" => %{"id" => _id, "attributes" => attrs}} = json_response(conn, 201)
      assert attrs["name"] == "Test Item"
    end
  end

  describe "PATCH /api/json/shopping_lists/:id/items/:item_id/toggle" do
    test "toggles checked state", %{conn: conn, shopping_list: list} do
      item = insert(:shopping_list_item, shopping_list: list, checked: false)

      conn = patch(conn, "/api/json/shopping_lists/#{list.id}/items/#{item.id}/toggle")

      assert %{"data" => %{"attributes" => %{"checked" => true}}} = json_response(conn, 200)
    end
  end
end
```

### Integration Tests

```elixir
defmodule GroceryPlannerWeb.Api.MobileWorkflowTest do
  use GroceryPlannerWeb.ConnCase

  test "complete shopping workflow via API" do
    # 1. Create shopping list
    # 2. Add items
    # 3. Check items off
    # 4. Complete list
    # Verify each step via API responses
  end

  test "recipe ingredient management via API" do
    # 1. Create recipe
    # 2. Add ingredients
    # 3. Update quantities
    # 4. Verify ingredient availability calculation
  end
end
```

### OpenAPI Validation

```bash
# Validate generated OpenAPI spec
npx @redocly/cli lint /api/json/open_api

# Test endpoints against spec
npx prism proxy /api/json/open_api http://localhost:4000
```

## Migration Path

### Phase 1: Database Schema Updates
1. Add `deleted_at` column to all syncable resources (migration)
2. Add indexes on `updated_at` and `deleted_at` columns
3. Run migrations in development and test environments

### Phase 2: Core Aggregate Routes (ShoppingList, Recipe, GroceryItem)
1. Add `AshJsonApi.Resource` extension to `ShoppingListItem`
2. Add `AshJsonApi.Resource` extension to `RecipeIngredient`
3. Change `InventoryEntry` routes from flat to nested
4. Add related routes to parent resources
5. Write tests for all new endpoints
6. Remove old `/inventory_entries` flat endpoint

### Phase 3: MealPlan Aggregate Routes
1. Add `AshJsonApi.Resource` extension to `MealPlanTemplate`
2. Add `AshJsonApi.Resource` extension to `MealPlanTemplateEntry`
3. Add `AshJsonApi.Resource` extension to `MealPlanVoteSession`
4. Add `AshJsonApi.Resource` extension to `MealPlanVoteEntry`
5. Add custom action routes (complete, skip, apply, close)
6. Write tests for all new endpoints

### Phase 4: Offline Sync Infrastructure
1. Add `:sync` read action to all syncable resources
2. Implement soft delete behavior (set `deleted_at` instead of hard delete)
3. Create `SyncController` with batch and status endpoints
4. Add sync routes to router
5. Write integration tests for sync workflows

### Phase 5: Documentation & Validation
1. Verify OpenAPI spec is complete and valid
2. Update Swagger UI configuration
3. Write mobile client integration guide
4. Document offline sync protocol

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| New endpoint adoption | 80% of requests use nested routes | API logs |
| Mobile app feature parity | 100% of web features available | Feature checklist |
| API response time (p95) | < 200ms | APM monitoring |
| Error rate | < 1% | Error tracking |
| OpenAPI spec validity | 100% valid | CI validation |

## Security Considerations

1. **Authorization Inheritance:** Child resources inherit authorization from parent aggregate
2. **Tenant Isolation:** All queries filtered by `account_id` via multitenancy
3. **Rate Limiting:** Apply per-endpoint rate limits (recommendation: 100 req/min per user)
4. **Input Validation:** All inputs validated via Ash action accepts/arguments
5. **CORS Configuration:** Ensure proper CORS headers for mobile app domains

## Open Questions

1. **Versioning Strategy:** Should we adopt `/api/v2/json` for breaking changes? (Not needed now since app isn't public)
2. **Pagination Defaults:** What page size should nested collections use? (Recommendation: 50)
3. **Sparse Fieldsets:** Should we optimize default field selection for mobile bandwidth?
4. ~~**Offline Sync:** Should we add `updated_at` filtering for incremental sync support?~~ **DECIDED: Yes, full offline sync**
5. ~~**Bulk Operations:** Should we support batch create/update for shopping list items?~~ **DECIDED: Yes, via /sync/batch**
6. ~~**Conflict Resolution:** What strategy for concurrent edits?~~ **DECIDED: Last-write-wins** (shared lists aren't a major use case)
7. **Sync Pagination:** How to handle large sync payloads? (Cursor-based with limit?)
8. **Offline Queue Limit:** Max number of offline operations before forcing sync?

## Dependencies

- `ash_json_api` ~> 1.0 (already installed)
- `open_api_spex` ~> 3.0 (already installed)

No new dependencies required.

## References

- [AshJsonApi Documentation](https://hexdocs.pm/ash_json_api)
- [JSON:API Specification](https://jsonapi.org/)
- [DDD Aggregate Pattern](https://martinfowler.com/bliki/DDD_Aggregate.html)
- [IMPLEMENTATION_PLAN.md - API Design Considerations](../IMPLEMENTATION_PLAN.md#api-design-considerations)
