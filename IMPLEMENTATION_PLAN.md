# GroceryPlanner Implementation Plan

## Overview

GroceryPlanner is a multi-tenant application for managing grocery inventory and meal planning. It tracks available groceries, provides meal planning capabilities, generates shopping lists, monitors expiration dates, and suggests recipes based on available inventory.

## Core Features

- Multi-tenant architecture supporting multiple users/households
- Grocery inventory management with quantities, prices, and use-by dates
- Recipe database with ingredient tracking
- Meal planning calendar
- Smart shopping list generation
- Expiration notifications and recipe suggestions
- Waste tracking and analytics

---

## Phase 1: Core Domain Model & Multi-Tenancy

### Resources

#### Account
- **Purpose:** Tenant resource representing a household or individual user
- **Fields:**
  - `name` (string) - Account/household name
  - `timezone` (string) - User's timezone for scheduling
  - `created_at` (datetime)
  - `updated_at` (datetime)

#### User
- **Purpose:** User authentication and profile
- **Fields:**
  - `email` (string, unique) - Login credential
  - `hashed_password` (string) - Encrypted password
  - `name` (string) - Display name
  - `confirmed_at` (datetime) - Email confirmation timestamp
  - `created_at` (datetime)
  - `updated_at` (datetime)

#### AccountMembership
- **Purpose:** Join table for multi-user households
- **Fields:**
  - `account_id` (uuid) - Foreign key to Account
  - `user_id` (uuid) - Foreign key to User
  - `role` (enum: owner, admin, member) - Permission level
  - `joined_at` (datetime)
- **Relationships:**
  - `belongs_to :account`
  - `belongs_to :user`

### Key Features
- Multi-tenancy using Ash's `:attribute` strategy on `account_id`
- User authentication with email/password
- Session management
- Household member invitations
- Role-based permissions

### Implementation Tasks
1. Generate Account resource with Ash
2. Generate User resource with authentication
3. Generate AccountMembership resource
4. Set up authentication plugs and session management
5. Create sign up / sign in LiveViews
6. Implement multi-tenancy context

---

## Phase 2: Inventory Management

### Resources

#### Category
- **Purpose:** Organize grocery items by type
- **Fields:**
  - `name` (string) - Category name (e.g., "Dairy", "Produce")
  - `icon` (string) - Icon identifier
  - `sort_order` (integer)
  - `account_id` (uuid, tenant attribute)
- **Multitenancy:** Scoped to account

#### StorageLocation
- **Purpose:** Track where items are stored
- **Fields:**
  - `name` (string) - Location name (e.g., "Fridge", "Pantry")
  - `temperature_zone` (enum: frozen, cold, cool, room_temp)
  - `account_id` (uuid, tenant attribute)
- **Multitenancy:** Scoped to account

#### GroceryItem
- **Purpose:** Master catalog of grocery items
- **Fields:**
  - `name` (string) - Item name
  - `description` (text) - Optional details
  - `category_id` (uuid) - Foreign key to Category
  - `default_unit` (string) - Default measurement unit
  - `barcode` (string, optional) - UPC/EAN for scanning
  - `account_id` (uuid, tenant attribute)
- **Relationships:**
  - `belongs_to :category`
  - `has_many :inventory_entries`
  - `has_many :recipe_ingredients`
- **Multitenancy:** Scoped to account

#### InventoryEntry
- **Purpose:** Specific instances of items in inventory
- **Fields:**
  - `grocery_item_id` (uuid) - Foreign key to GroceryItem
  - `storage_location_id` (uuid) - Foreign key to StorageLocation
  - `quantity` (decimal) - Amount in stock
  - `unit` (string) - Measurement unit
  - `purchase_price` (money) - Price paid
  - `purchase_date` (date) - When purchased
  - `use_by_date` (date) - Expiration date
  - `notes` (text) - Additional info
  - `status` (enum: available, reserved, expired, consumed) - Current state
  - `account_id` (uuid, tenant attribute)
- **Relationships:**
  - `belongs_to :grocery_item`
  - `belongs_to :storage_location`
- **Calculations:**
  - `days_until_expiry` - Days remaining before use_by_date
  - `is_expiring_soon` - Boolean if expiring within X days
  - `is_expired` - Boolean if past use_by_date
- **Multitenancy:** Scoped to account

### Key Features
- Add/edit/remove inventory items
- Track quantities with flexible units
- Price and expiration date tracking
- Storage location organization
- Barcode scanning support (future)
- Bulk import/export

### Implementation Tasks
1. Generate Category resource
2. Generate StorageLocation resource
3. Generate GroceryItem resource
4. Generate InventoryEntry resource with calculations
5. Create inventory management LiveView
6. Implement filters and search
7. Add bulk operations

---

## Phase 3: Recipe System

### Resources

#### RecipeTag
- **Purpose:** Categorize and filter recipes
- **Fields:**
  - `name` (string) - Tag name (e.g., "Vegetarian", "Quick")
  - `color` (string) - Display color
  - `account_id` (uuid, tenant attribute)
- **Multitenancy:** Scoped to account

#### Recipe
- **Purpose:** Store recipe information
- **Fields:**
  - `name` (string) - Recipe name
  - `description` (text) - Brief description
  - `instructions` (text) - Cooking steps
  - `prep_time_minutes` (integer) - Preparation time
  - `cook_time_minutes` (integer) - Cooking time
  - `servings` (integer) - Default serving size
  - `difficulty` (enum: easy, medium, hard)
  - `image_url` (string, optional) - Recipe photo
  - `source` (string, optional) - Where recipe came from
  - `is_favorite` (boolean) - User favorite flag
  - `account_id` (uuid, tenant attribute)
- **Relationships:**
  - `has_many :recipe_ingredients`
  - `many_to_many :tags` (through RecipeTagging)
  - `has_many :meal_plans`
- **Calculations:**
  - `total_time_minutes` - Sum of prep and cook time
  - `ingredient_availability` - Percentage of ingredients in stock
  - `can_make` - Boolean if all required ingredients available
  - `missing_ingredients` - List of ingredients not in inventory
- **Aggregates:**
  - `times_cooked` - Count of completed meal plans
- **Multitenancy:** Scoped to account

#### RecipeIngredient
- **Purpose:** Link recipes to ingredients with quantities
- **Fields:**
  - `recipe_id` (uuid) - Foreign key to Recipe
  - `grocery_item_id` (uuid) - Foreign key to GroceryItem
  - `quantity` (decimal) - Amount needed
  - `unit` (string) - Measurement unit
  - `is_optional` (boolean) - Whether ingredient is optional
  - `substitution_notes` (text) - Alternative ingredients
  - `preparation` (string) - How to prepare (e.g., "diced", "minced")
  - `sort_order` (integer) - Display order
  - `account_id` (uuid, tenant attribute)
- **Relationships:**
  - `belongs_to :recipe`
  - `belongs_to :grocery_item`
- **Multitenancy:** Scoped to account

### Key Features
- Recipe creation and editing
- Ingredient management with quantities
- Recipe scaling based on servings
- Tag-based filtering
- Recipe search and favorites
- Import recipes from URLs (future)
- Recipe sharing between accounts (future)

### Implementation Tasks
1. Generate RecipeTag resource
2. Generate Recipe resource with calculations
3. Generate RecipeIngredient resource
4. Create recipe browsing LiveView
5. Create recipe detail/edit LiveView
6. Implement recipe search and filters
7. Add ingredient availability indicators

---

## Phase 4: Meal Planning

### Resources

#### MealPlan
- **Purpose:** Schedule recipes for specific dates and meals
- **Fields:**
  - `recipe_id` (uuid) - Foreign key to Recipe
  - `scheduled_date` (date) - When to prepare
  - `meal_type` (enum: breakfast, lunch, dinner, snack) - Type of meal
  - `servings` (integer) - Number of servings to prepare
  - `notes` (text) - Additional notes
  - `status` (enum: planned, completed, skipped) - Current state
  - `completed_at` (datetime) - When marked complete
  - `account_id` (uuid, tenant attribute)
- **Relationships:**
  - `belongs_to :recipe`
- **Calculations:**
  - `scaled_ingredients` - Recipe ingredients adjusted for servings
  - `requires_shopping` - Boolean if missing ingredients
- **Multitenancy:** Scoped to account

#### MealPlanTemplate
- **Purpose:** Reusable weekly meal patterns
- **Fields:**
  - `name` (string) - Template name
  - `is_active` (boolean) - Currently in use
  - `account_id` (uuid, tenant attribute)
- **Relationships:**
  - `has_many :template_entries`
- **Multitenancy:** Scoped to account

#### MealPlanTemplateEntry
- **Purpose:** Individual meals in a template
- **Fields:**
  - `template_id` (uuid) - Foreign key to MealPlanTemplate
  - `recipe_id` (uuid) - Foreign key to Recipe
  - `day_of_week` (integer) - 0-6 for Sunday-Saturday
  - `meal_type` (enum: breakfast, lunch, dinner, snack)
  - `servings` (integer)
- **Relationships:**
  - `belongs_to :template`
  - `belongs_to :recipe`

### Key Features
- Calendar view of meal plans
- Drag-and-drop meal scheduling
- Meal plan templates for repeating schedules
- Check ingredient availability before planning
- Serve size adjustments
- Copy previous week's plan
- Mark meals as completed

### Implementation Tasks
1. Generate MealPlan resource with calculations
2. Generate MealPlanTemplate resources
3. Create meal calendar LiveView
4. Implement drag-and-drop scheduling
5. Add template management
6. Create quick-add meal interface

---

## Phase 5: Shopping Lists

### Resources

#### ShoppingList
- **Purpose:** Track items to purchase
- **Fields:**
  - `name` (string) - List name
  - `status` (enum: draft, active, completed) - Current state
  - `created_at` (datetime)
  - `completed_at` (datetime, optional)
  - `account_id` (uuid, tenant attribute)
- **Relationships:**
  - `has_many :shopping_list_items`
- **Aggregates:**
  - `total_items` - Count of items
  - `checked_items` - Count of checked items
  - `estimated_total` - Sum of estimated prices
- **Calculations:**
  - `completion_percentage` - Percent of items checked
- **Multitenancy:** Scoped to account

#### ShoppingListItem
- **Purpose:** Individual items to purchase
- **Fields:**
  - `shopping_list_id` (uuid) - Foreign key to ShoppingList
  - `grocery_item_id` (uuid, optional) - Foreign key to GroceryItem
  - `name` (string) - Item name (if not linked to GroceryItem)
  - `quantity` (decimal) - Amount to buy
  - `unit` (string) - Measurement unit
  - `estimated_price` (money, optional) - Expected cost
  - `actual_price` (money, optional) - Actual cost paid
  - `is_checked` (boolean) - Marked as purchased
  - `notes` (text) - Additional info
  - `sort_order` (integer)
  - `account_id` (uuid, tenant attribute)
- **Relationships:**
  - `belongs_to :shopping_list`
  - `belongs_to :grocery_item` (optional)
- **Multitenancy:** Scoped to account

### Key Features
- Auto-generate lists from meal plans
- Calculate missing ingredients for recipes
- Manual list creation and editing
- Check off items as purchased
- Track estimated vs actual prices
- Add checked items directly to inventory
- Share lists with household members
- Print-friendly format

### Implementation Tasks
1. Generate ShoppingList resource with aggregates
2. Generate ShoppingListItem resource
3. Create action to generate list from meal plans
4. Build shopping list management LiveView
5. Implement check-off functionality
6. Add "add to inventory" quick action
7. Create printable view

---

## Phase 6: Smart Notifications & Recommendations

### Calculated Resources & Actions

#### ExpirationAlert
- **Purpose:** Notification calculation for expiring items
- **Type:** Ash calculation/query
- **Logic:**
  - Query inventory entries where `days_until_expiry` <= threshold
  - Group by urgency (today, tomorrow, this week)
  - Include item details and suggested actions

#### RecipeSuggestion
- **Purpose:** Recommend recipes using expiring ingredients
- **Type:** Ash calculation/custom action
- **Logic:**
  - Find recipes that use ingredients expiring soon
  - Rank by number of expiring ingredients used
  - Check if other required ingredients are available
  - Return top suggestions with "use it up" score

#### UsageAnalytics
- **Purpose:** Track consumption patterns
- **Type:** Aggregates and reports
- **Metrics:**
  - Most/least used items
  - Average time between purchase and use
  - Waste percentage (expired items)
  - Cost per meal
  - Inventory turnover rate

### Key Features
- Configurable notification preferences
- Email/in-app expiration alerts
- "Use it up" recipe recommendations
- Waste tracking and reporting
- Inventory value calculations
- Consumption trend analysis
- Smart restocking suggestions

### Implementation Tasks
1. Create expiration alert calculation
2. Build recipe suggestion algorithm
3. Implement notification system
4. Create usage analytics queries
5. Add notification preferences UI
6. Build analytics dashboard
7. Implement email notifications

---

## Phase 7: User Interface (LiveView)

### Pages & Routes

#### 1. Authentication
- `/` - Landing page
- `/sign-up` - User registration
- `/sign-in` - User login
- `/sign-out` - Logout
- `/reset-password` - Password reset

#### 2. Dashboard (`/dashboard`)
- Overview cards: total items, expiring soon, meal plans this week
- Quick stats: inventory value, items to buy, recipes available
- Upcoming expirations list
- This week's meal calendar
- Recent activity feed

#### 3. Inventory (`/inventory`)
- List/grid view with item cards
- Filters: category, storage location, expiring soon
- Search functionality
- Quick add form
- Bulk operations
- Detail modal for editing

#### 4. Recipes (`/recipes`)
- Recipe cards with images
- Tag-based filtering
- Search by name or ingredient
- Sort by: name, cook time, difficulty, times cooked
- Favorite recipes section
- `/recipes/:id` - Recipe detail with ingredient availability

#### 5. Meal Planner (`/meal-planner`)
- Weekly/monthly calendar view
- Drag-and-drop recipes onto dates
- Daily meal type sections (breakfast, lunch, dinner)
- Template management
- Generate shopping list button

#### 6. Shopping Lists (`/shopping`)
- Active lists overview
- Create new list
- `/shopping/:id` - List detail with check-off items
- Auto-generate from meal plans
- Print view

#### 7. Settings (`/settings`)
- Account/household management
- User profile
- Notification preferences
- Storage locations
- Categories
- Member management
- Data export

#### 8. Analytics (`/analytics`)
- Inventory value trends
- Waste metrics
- Most/least used items
- Cost per meal analysis
- Shopping patterns

### UI/UX Features
- Real-time updates with LiveView
- Mobile-responsive design with Tailwind CSS
- Toast notifications for actions
- Loading states and optimistic updates
- Keyboard shortcuts for power users
- Dark mode support
- Accessibility (ARIA labels, keyboard navigation)

### Implementation Tasks
1. Create authentication LiveViews
2. Build dashboard with overview cards
3. Create inventory management interface
4. Build recipe browsing and detail views
5. Implement meal planner calendar
6. Create shopping list interfaces
7. Build settings pages
8. Add analytics dashboard
9. Implement responsive design
10. Add accessibility features

---

## Phase 8: Dashboard & Analytics

### Key Metrics & Visualizations

#### Inventory Metrics
- Total items in stock
- Total inventory value
- Items expiring in next 7 days
- Items by category breakdown
- Items by storage location
- Low stock alerts

#### Recipe & Meal Planning Metrics
- Total recipes available
- Recipes can make right now
- Meals planned this week/month
- Most cooked recipes
- Average cost per meal
- Time saved with meal planning

#### Shopping & Cost Metrics
- Active shopping lists
- Items to purchase
- Estimated shopping cost
- Spending trends over time
- Price comparisons over time
- Budget vs actual spending

#### Waste & Sustainability Metrics
- Items expired/wasted
- Waste cost (value of expired items)
- Waste reduction percentage
- Most wasted items
- Recommendations to reduce waste

### Visualization Types
- Line charts for trends over time
- Bar charts for comparisons
- Pie charts for category breakdowns
- Tables for detailed lists
- Progress bars for completion percentages
- Heatmaps for usage patterns

### Implementation Tasks
1. Define analytics queries as Ash calculations
2. Create data aggregation pipelines
3. Build chart components
4. Implement dashboard widgets
5. Add date range filters
6. Create exportable reports
7. Add goal tracking features

---

## Technical Architecture

### Directory Structure

```
lib/grocery_planner/
├── accounts/
│   ├── account.ex
│   ├── user.ex
│   ├── account_membership.ex
│   └── resources.ex
├── inventory/
│   ├── category.ex
│   ├── storage_location.ex
│   ├── grocery_item.ex
│   ├── inventory_entry.ex
│   └── resources.ex
├── recipes/
│   ├── recipe.ex
│   ├── recipe_ingredient.ex
│   ├── recipe_tag.ex
│   └── resources.ex
├── meal_planning/
│   ├── meal_plan.ex
│   ├── meal_plan_template.ex
│   ├── meal_plan_template_entry.ex
│   └── resources.ex
├── shopping/
│   ├── shopping_list.ex
│   ├── shopping_list_item.ex
│   └── resources.ex
├── notifications/
│   ├── notification_preference.ex
│   └── notifier.ex
└── analytics/
    └── calculations.ex

lib/grocery_planner_web/
├── live/
│   ├── auth/
│   │   ├── sign_up_live.ex
│   │   └── sign_in_live.ex
│   ├── dashboard_live.ex
│   ├── inventory/
│   │   ├── index_live.ex
│   │   └── form_component.ex
│   ├── recipes/
│   │   ├── index_live.ex
│   │   ├── show_live.ex
│   │   └── form_component.ex
│   ├── meal_planner/
│   │   └── index_live.ex
│   ├── shopping/
│   │   ├── index_live.ex
│   │   └── show_live.ex
│   ├── settings/
│   │   └── index_live.ex
│   └── analytics/
│       └── index_live.ex
└── components/
    ├── inventory_card.ex
    ├── recipe_card.ex
    ├── meal_calendar.ex
    └── charts.ex
```

### Multi-Tenancy Strategy

**Approach:** Ash's `:attribute` strategy on `account_id`

**Implementation:**
- All resources except `User` and `Account` have `account_id` field
- Ash automatically filters all queries by current account
- Context/plug sets current account from authenticated user
- Database indexes on `account_id` for performance

**Benefits:**
- Data isolation between accounts
- Simple to understand and maintain
- Flexible for future enhancements
- Works well with PostgreSQL row-level security (optional)

### Key Ash Features to Leverage

#### 1. Calculations
- `days_until_expiry` on InventoryEntry
- `ingredient_availability` on Recipe
- `completion_percentage` on ShoppingList
- `can_make` on Recipe (all ingredients available)

#### 2. Aggregates
- `total_items` on ShoppingList
- `times_cooked` on Recipe
- `total_inventory_value` on Account
- `expiring_items_count` on Account

#### 3. Actions
- Custom action: `generate_shopping_list_from_meal_plans`
- Custom action: `add_to_inventory_from_shopping_item`
- Custom action: `mark_meal_complete_and_consume_inventory`
- Custom action: `suggest_recipes_for_expiring_items`

#### 4. Policies
- Ensure users only access their account's data
- Role-based permissions (owner, admin, member)
- Resource-level authorization rules

#### 5. Validations
- `use_by_date` must be after `purchase_date`
- `quantity` must be greater than 0
- `servings` must be at least 1
- Email format validation
- Unique constraints on names within account

---

## Database Considerations

### Indexes
- `account_id` on all tenant-scoped tables
- Composite indexes: `(account_id, status)`, `(account_id, use_by_date)`
- Search indexes on `name` fields
- Foreign key indexes

### Data Types
- Money fields using `ex_money_sql` for proper currency handling
- Dates for expiration tracking (not timestamps)
- Decimal for quantities (avoid float precision issues)
- JSONB for flexible metadata storage (future)

### Performance
- Eager loading with `Ash.Query.load/2` for associations
- Pagination on list views
- Background jobs for analytics calculations
- Caching for frequently accessed data

---

## Security Considerations

1. **Authentication:** Email/password with proper hashing
2. **Authorization:** Ash policies enforce tenant isolation
3. **CSRF Protection:** Phoenix built-in protection
4. **SQL Injection:** Ash handles parameterization
5. **XSS Protection:** Phoenix auto-escapes HTML
6. **Rate Limiting:** Implement for login attempts
7. **Password Requirements:** Minimum length, complexity rules

---

## Testing Strategy

### Unit Tests
- Ash resource tests for all CRUD operations
- Calculation tests with various scenarios
- Validation tests for edge cases
- Policy tests for authorization rules

### Integration Tests
- Multi-step workflows (add to cart → generate list)
- Multi-tenancy isolation verification
- Complex queries with joins and calculations

### LiveView Tests
- Page rendering with correct data
- Form submissions and validations
- User interactions (clicks, typing)
- Real-time updates

### End-to-End Tests
- Complete user workflows
- Authentication flows
- Multi-user scenarios
- Browser compatibility

---

## Future Enhancements

### Phase 9+: Advanced Features
- **Barcode Scanning:** Mobile camera integration for adding items
- **Voice Commands:** Alexa/Google Home integration
- **AI Recipe Suggestions:** ML-based personalized recommendations
- **Nutrition Tracking:** Calories, macros, dietary restrictions
- **Budget Management:** Set spending limits, track against budget
- **Social Features:** Share recipes with friends, meal planning challenges
- **Mobile Apps:** Native iOS/Android apps
- **Integrations:** Import from grocery stores, recipe websites
- **Advanced Analytics:** Predictive restocking, seasonal trend analysis
- **Gamification:** Badges for waste reduction, cooking streaks

---

## Development Timeline Estimate

**Phase 1:** Core Domain Model - 1 week
**Phase 2:** Inventory Management - 2 weeks
**Phase 3:** Recipe System - 2 weeks
**Phase 4:** Meal Planning - 1.5 weeks
**Phase 5:** Shopping Lists - 1.5 weeks
**Phase 6:** Notifications - 1 week
**Phase 7:** User Interface - 3 weeks
**Phase 8:** Dashboard & Analytics - 1.5 weeks

**Total:** ~13-14 weeks for MVP

---

## Success Metrics

### User Engagement
- Daily active users
- Average session duration
- Features used per session
- User retention rate

### Value Delivered
- Food waste reduction percentage
- Money saved on groceries
- Time saved on meal planning
- Recipes cooked per week

### Technical Performance
- Page load times < 2 seconds
- Query response times < 500ms
- Zero downtime deployments
- Test coverage > 80%

---

## Conclusion

This implementation plan provides a comprehensive roadmap for building GroceryPlanner as a robust, multi-tenant application using Elixir, Phoenix, Ash Framework, and LiveView. The phased approach allows for iterative development with each phase building upon the previous foundation.

The use of Ash Framework provides powerful features like calculations, aggregates, and policies that make complex domain logic clean and maintainable. Phoenix LiveView enables real-time, interactive user experiences without writing JavaScript. Together, these technologies create a solid foundation for a feature-rich grocery and meal planning application.
