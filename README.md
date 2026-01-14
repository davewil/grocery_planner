# GroceryPlanner

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Install git hooks with `./scripts/install-git-hooks.sh` (recommended for development)
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## JSON:API

GroceryPlanner provides a JSON:API for mobile and third-party integrations.

### Authentication

The API uses token-based authentication. First, obtain a token by signing in:

```bash
curl -X POST http://localhost:4000/api/sign-in \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "your_password"}'
```

Response:
```json
{
  "data": {
    "token": "SFMyNTY...",
    "user_id": "uuid",
    "email": "user@example.com",
    "name": "Your Name"
  }
}
```

### Making Authenticated Requests

Include the token in the `Authorization` header for all API requests:

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Accept: application/vnd.api+json" \
  http://localhost:4000/api/json/grocery_items
```

### Available Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/sign-in` | Authenticate and get token |
| **Inventory** | | |
| GET | `/api/json/grocery_items` | List grocery items |
| GET | `/api/json/grocery_items/:id` | Get a grocery item |
| POST | `/api/json/grocery_items` | Create a grocery item |
| PATCH | `/api/json/grocery_items/:id` | Update a grocery item |
| DELETE | `/api/json/grocery_items/:id` | Delete a grocery item |
| GET | `/api/json/categories` | List categories |
| GET | `/api/json/storage_locations` | List storage locations |
| GET | `/api/json/inventory_entries` | List inventory entries |
| **Recipes** | | |
| GET | `/api/json/recipes` | List recipes |
| GET | `/api/json/recipes/:id` | Get a recipe |
| POST | `/api/json/recipes` | Create a recipe |
| PATCH | `/api/json/recipes/:id` | Update a recipe |
| DELETE | `/api/json/recipes/:id` | Delete a recipe |
| **Shopping** | | |
| GET | `/api/json/shopping_lists` | List shopping lists |
| GET | `/api/json/shopping_lists/:id` | Get a shopping list |
| POST | `/api/json/shopping_lists` | Create a shopping list |
| PATCH | `/api/json/shopping_lists/:id` | Update a shopping list |
| DELETE | `/api/json/shopping_lists/:id` | Delete a shopping list |
| **Meal Planning** | | |
| GET | `/api/json/meal_plans` | List meal plans |
| GET | `/api/json/meal_plans/:id` | Get a meal plan |
| POST | `/api/json/meal_plans` | Create a meal plan |
| PATCH | `/api/json/meal_plans/:id` | Update a meal plan |
| DELETE | `/api/json/meal_plans/:id` | Delete a meal plan |
| **Notifications** | | |
| GET | `/api/json/notification_preferences` | List notification preferences |
| GET | `/api/json/notification_preferences/:id` | Get notification preference |
| POST | `/api/json/notification_preferences` | Create notification preference |
| PATCH | `/api/json/notification_preferences/:id` | Update notification preference |
| DELETE | `/api/json/notification_preferences/:id` | Delete notification preference |
| **Analytics** | | |
| GET | `/api/json/usage_logs` | List usage logs (consumption/waste) |
| GET | `/api/json/usage_logs/:id` | Get a usage log |
| **OpenAPI** | | |
| GET | `/api/json/open_api` | OpenAPI specification |

### Example: Create a Grocery Item

```bash
curl -X POST http://localhost:4000/api/json/grocery_items \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -H "Accept: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "grocery_item",
      "attributes": {
        "name": "Milk",
        "description": "Whole milk",
        "default_unit": "gallon"
      }
    }
  }'
```

### OpenAPI Specification

The full OpenAPI specification is available at `/api/json/open_api` and can be used with tools like Swagger UI or Postman.

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
