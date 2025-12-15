# GroceryPlanner

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
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
| GET | `/api/json/grocery_items` | List grocery items |
| GET | `/api/json/grocery_items/:id` | Get a grocery item |
| POST | `/api/json/grocery_items` | Create a grocery item |
| PATCH | `/api/json/grocery_items/:id` | Update a grocery item |
| DELETE | `/api/json/grocery_items/:id` | Delete a grocery item |
| GET | `/api/json/categories` | List categories |
| GET | `/api/json/storage_locations` | List storage locations |
| GET | `/api/json/inventory_entries` | List inventory entries |
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
