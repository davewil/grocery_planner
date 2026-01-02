# GroceryPlanner Project Context for Gemini

## Project Overview

GroceryPlanner is a comprehensive grocery management system built with **Elixir**, **Phoenix**, and the **Ash Framework**. It is designed to handle inventory tracking, recipe management, shopping list generation, and collaborative meal planning. The application exposes both a **JSON:API** for external integrations and a **Phoenix LiveView** web interface for user interaction.

## Technology Stack

*   **Language:** Elixir (~> 1.15)
*   **Web Framework:** Phoenix (~> 1.8.1)
*   **Application Framework:** Ash Framework (~> 3.0)
    *   **Data Layer:** `ash_postgres` (PostgreSQL 18+)
    *   **API:** `ash_json_api`
    *   **Types:** `ash_money`
*   **Database:** PostgreSQL (requires `citext`, `ash-functions` extensions)
*   **Frontend:**
    *   Phoenix LiveView (~> 1.1.0)
    *   Tailwind CSS v4 (No `tailwind.config.js`, uses CSS imports)
    *   Esbuild
*   **HTTP Client:** `Req` (Preferred over HTTPoison/Tesla)

## Architecture

The application is structured around **Ash Domains** (formerly APIs) which encapsulate business logic and data access.

### Core Domains (`lib/grocery_planner/`)

1.  **Accounts** (`GroceryPlanner.Accounts`)
    *   **Resources:** `User`, `Account`, `AccountMembership`.
    *   **Functionality:** Authentication (password/bcrypt), multi-tenancy support, user management.
2.  **Inventory** (`GroceryPlanner.Inventory`)
    *   **Resources:** `GroceryItem`, `Category`, `StorageLocation`, `InventoryEntry`.
    *   **Functionality:** Tracking item quantities, locations, and expiration dates.
3.  **Recipes** (`GroceryPlanner.Recipes`)
    *   **Resources:** `Recipe`, `RecipeIngredient`, `RecipeTag`.
    *   **Functionality:** Recipe creation, ingredient linking, categorization.
4.  **Shopping** (`GroceryPlanner.Shopping`)
    *   **Resources:** `ShoppingList`, `ShoppingListItem`.
    *   **Functionality:** Managing shopping needs.
5.  **MealPlanning** (`GroceryPlanner.MealPlanning`)
    *   **Resources:** `MealPlan`, `MealPlanVoteSession`, `MealPlanTemplate`.
    *   **Functionality:** Collaborative planning and voting on meals.
6.  **Notifications** (`GroceryPlanner.Notifications`)
    *   **Resources:** `NotificationPreference`, `ExpirationAlerts`.
    *   **Functionality:** User alert settings.
7.  **Analytics** (`GroceryPlanner.Analytics`)
    *   **Resources:** `UsageLog`.
    *   **Functionality:** Tracking consumption and waste.

### Web Layer (`lib/grocery_planner_web/`)

*   **Router:** `GroceryPlannerWeb.Router` handles HTTP request routing, defining `:browser` and `:api` pipelines.
*   **Authentication:** `GroceryPlannerWeb.Auth` plug manages user sessions.
*   **LiveViews:** located in `lib/grocery_planner_web/live/`, managing interactive UI (Dashboard, Inventory, Settings, etc.).
*   **Components:** `GroceryPlannerWeb.CoreComponents` contains reusable UI elements (inputs, modals, tables) styled with Tailwind.
*   **API:** JSON:API endpoints are automatically generated from Ash resources.

## Development Workflow

### Setup & Run
*   **Install Dependencies & Setup:** `mix setup` (Installs deps, sets up DB, seeds data)
*   **Start Server:** `mix phx.server` (Runs at `http://localhost:4000`)
*   **Interactive Shell:** `iex -S mix phx.server`

### Testing & Quality
*   **Run Tests:** `mix test` (Automatically runs `ash.setup --quiet`)
*   **Run Specific Test:** `mix test test/path/to/test.exs`
*   **Pre-commit Check:** `mix precommit` (Compiles --warnings-as-errors, formats, lints, tests)

### Database Management (Ash)
*   **Setup:** `mix ash.setup`
*   **Reset:** `mix ash.reset` (Drops and recreates DB)
*   **Migrate:** `mix ash.migrate`
*   **Rollback:** `mix ash.rollback`

### Asset Management
*   **Setup:** `mix assets.setup` (Installs Tailwind/Esbuild)
*   **Build:** `mix assets.build`
*   **Deploy:** `mix assets.deploy` (Minifies for production)

## Key Conventions

*   **Ash First:** All business logic and data access should go through Ash Resources. Use `code_interface` defined in resources or `Ash.Query` for interactions.
*   **LiveView Streams:** Use `stream` for handling collections in LiveViews to optimize memory usage.
*   **Tailwind v4:** Use the new import syntax in `assets/css/app.css`. Do not look for a config file.
*   **Components:** Prefer using `GroceryPlannerWeb.CoreComponents` (e.g., `<.input>`, `<.table>`) over raw HTML or external UI libraries.
*   **Icons:** Use the `<.icon name="hero-name" />` component.
*   **HTTP:** Use `Req` for external API calls.

## Important Files

*   `mix.exs`: Project dependencies and aliases.
*   `lib/grocery_planner/repo.ex`: Database repository configuration.
*   `lib/grocery_planner_web/router.ex`: Route definitions.
*   `AGENTS.md` & `CLAUDE.md`: Specific behavioral guidelines for AI agents.
