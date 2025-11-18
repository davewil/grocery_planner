# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### Development Setup
- `mix setup` - Install dependencies, setup database, build assets, and run seeds
- `mix phx.server` - Start Phoenix server at http://localhost:4000
- `iex -S mix phx.server` - Start Phoenix server with IEx interactive shell

### Testing and Quality
- `mix test` - Run all tests (automatically runs `ash.setup --quiet` first)
- `mix test test/path/to/test.exs` - Run a specific test file
- `mix test --failed` - Run only previously failed tests
- `mix precommit` - Full pre-commit check: compile with warnings as errors, clean unused deps, format code, and run tests

### Database Management
- `mix ash.setup` - Create database, run migrations (uses Ash's database setup)
- `mix ash.reset` - Drop and recreate database
- `mix ash.migrate` - Run pending migrations
- `mix ash.rollback` - Rollback the last migration

### Asset Management
- `mix assets.setup` - Install Tailwind and esbuild if missing
- `mix assets.build` - Compile and build all assets (Tailwind + esbuild)
- `mix assets.deploy` - Build minified assets for production

## Architecture Overview

### Ash Framework
This application uses the **Ash Framework** (v3.0) as its core data layer and business logic engine. Ash provides declarative resource definitions with built-in validation, authorization, code interfaces, and database operations.

**Key Concepts:**
- **Resources**: Define data structures, actions, validations, and policies (e.g., `GroceryPlanner.Accounts.User`)
- **Domains**: Group related resources together (e.g., `GroceryPlanner.Accounts`, `GroceryPlanner.Inventory`)
- **Actions**: Declarative CRUD operations with custom logic via changes and validations
- **Policies**: Authorization rules defined directly in resources
- **Code Interfaces**: Automatically generated functions for interacting with resources

**Database Layer**: Uses `AshPostgres` data layer with PostgreSQL 18+ required. The repo is `GroceryPlanner.Repo` which extends `AshPostgres.Repo`.

### Domain Organization

**Accounts Domain** (`GroceryPlanner.Accounts`)
- Multi-tenancy support via Account/User/AccountMembership pattern
- Resources: `User`, `Account`, `AccountMembership`
- User authentication with bcrypt password hashing
- Email confirmation workflow

**Inventory Domain** (`GroceryPlanner.Inventory`)
- Resources: `Category`, `StorageLocation`, `GroceryItem`, `InventoryEntry`
- Supports tracking grocery items across storage locations with quantities and expiration

### Web Layer (Phoenix LiveView)

**Authentication**
- Custom authentication plug: `GroceryPlannerWeb.Auth`
- Pipelines: `:browser`, `:require_authenticated_user`
- Public routes: sign-up, sign-in
- Protected routes: dashboard, settings, inventory

**LiveViews**
- `Auth.SignUpLive` / `Auth.SignInLive` - User registration and login
- `DashboardLive` - Main authenticated dashboard
- `SettingsLive` - User settings
- `InventoryLive` - Inventory management

**Component Architecture**
- Core components in `GroceryPlannerWeb.CoreComponents`
- Layouts in `GroceryPlannerWeb.Layouts` module
- Hero icons via `<.icon>` component

### Working with Ash Resources

**Creating Resources:**
```elixir
use Ash.Resource,
  domain: GroceryPlanner.DomainName,
  data_layer: AshPostgres.DataLayer,
  authorizers: [Ash.Policy.Authorizer]

postgres do
  table "table_name"
  repo GroceryPlanner.Repo
end
```

**Defining Actions:**
- Use `defaults [:read, :update, :destroy]` for standard CRUD
- Custom actions require explicit definition
- Use `code_interface` to generate helper functions

**Querying Resources:**
```elixir
# Via code interface
GroceryPlanner.Accounts.User.by_email!("user@example.com")

# Via Ash.Query
User
|> Ash.Query.filter(email == "user@example.com")
|> Ash.read_one!()
```

**Changes and Validations:**
- Use `change` callbacks in actions to modify data
- Define custom validations in the `validations` section
- Leverage built-in Ash validations

### Configuration Notes

**Ash Configuration** (`config/config.exs`)
- Domains registered: `GroceryPlanner.Accounts`, `GroceryPlanner.Inventory`
- Custom type support for `AshMoney.Types.Money`
- Formatter settings for Ash resources in `.formatter.exs`

**Extensions Installed:**
- PostgreSQL extensions: `ash-functions`, `citext`, `AshMoney.AshPostgresExtension`
- Requires PostgreSQL 18.0+

**Phoenix Configuration:**
- Uses Bandit adapter (not Cowboy)
- Tailwind CSS v4 (no tailwind.config.js needed)
- esbuild for JavaScript bundling

### Important Development Patterns

**Multi-Tenancy:**
- Account-based multi-tenancy is implemented via relationships
- Users belong to multiple Accounts via AccountMembership
- Inventory resources are scoped to Accounts

**Authentication Flow:**
- Password hashing with bcrypt happens in User resource action changes
- Sensitive attributes (`:hashed_password`) marked with `sensitive?: true`
- Email confirmation via `:confirm` action

**Asset Pipeline:**
- CSS in `assets/css/app.css` with Tailwind v4 import syntax
- JavaScript in `assets/js/app.js`
- No inline scripts in templates - use JS hooks instead

For detailed Phoenix and LiveView guidelines, see the comprehensive rules in AGENTS.md.
