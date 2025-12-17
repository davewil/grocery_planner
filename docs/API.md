# GroceryPlanner API Documentation

_Last Updated: December 16, 2025_

## Overview

GroceryPlanner provides a JSON:API compliant REST API for managing grocery inventory, recipes, meal planning, and shopping lists. All API endpoints follow the [JSON:API specification](https://jsonapi.org/).

## Base URL

```
/api/json
```

## Authentication

All API endpoints (except `/api/sign-in`) require Bearer token authentication.

### Getting a Token

```bash
POST /api/sign-in
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "your_password"
}
```

**Response:**
```json
{
  "token": "SFMyNTY...",
  "user": {
    "id": "uuid",
    "email": "user@example.com"
  }
}
```

### Using the Token

Include the token in all subsequent requests:

```bash
Authorization: Bearer SFMyNTY...
```

Token expires after 24 hours.

---

## OpenAPI Specification

An auto-generated OpenAPI 3.0 specification is available at:

```
GET /api/json/open_api
```

This can be imported into Swagger UI, Postman, or other API tools.

---

## Interactive Documentation (Swagger UI)

Swagger UI is available for interactive API exploration:

```
GET /api/swaggerui
```

This provides a web interface where you can:
- Browse all available endpoints
- View request/response schemas
- Try API calls directly from the browser (after authentication)

---

## Domains & Resources

### Inventory Domain

#### Categories
Organize grocery items by type (Produce, Dairy, etc.)

| Method | Endpoint | Action |
|--------|----------|--------|
| GET | `/categories` | List all categories |
| GET | `/categories/:id` | Get single category |
| POST | `/categories` | Create category |
| PATCH | `/categories/:id` | Update category |
| DELETE | `/categories/:id` | Delete category |

**Attributes:**
- `name` (string, required)
- `icon` (string)
- `sort_order` (integer, default: 0)

---

#### Storage Locations
Track where items are stored (Fridge, Pantry, etc.)

| Method | Endpoint | Action |
|--------|----------|--------|
| GET | `/storage_locations` | List all locations |
| GET | `/storage_locations/:id` | Get single location |
| POST | `/storage_locations` | Create location |
| PATCH | `/storage_locations/:id` | Update location |
| DELETE | `/storage_locations/:id` | Delete location |

**Attributes:**
- `name` (string, required)
- `temperature_zone` (enum: frozen, cold, cool, room_temp)

---

#### Grocery Items
Master catalog of grocery products

| Method | Endpoint | Action |
|--------|----------|--------|
| GET | `/grocery_items` | List all items |
| GET | `/grocery_items/:id` | Get single item |
| POST | `/grocery_items` | Create item |
| PATCH | `/grocery_items/:id` | Update item |
| DELETE | `/grocery_items/:id` | Delete item |

**Attributes:**
- `name` (string, required)
- `description` (string)
- `default_unit` (string)
- `barcode` (string)
- `category_id` (uuid)

---

#### Inventory Entries
Specific instances of items in stock

| Method | Endpoint | Action |
|--------|----------|--------|
| GET | `/inventory_entries` | List all entries |
| GET | `/inventory_entries/:id` | Get single entry |
| POST | `/inventory_entries` | Create entry |
| PATCH | `/inventory_entries/:id` | Update entry |
| DELETE | `/inventory_entries/:id` | Delete entry |

**Attributes:**
- `quantity` (decimal, required)
- `unit` (string)
- `purchase_price` (money)
- `purchase_date` (date)
- `use_by_date` (date)
- `notes` (string)
- `status` (enum: available, reserved, expired, consumed)
- `grocery_item_id` (uuid, required)
- `storage_location_id` (uuid)

**Calculations (read-only):**
- `days_until_expiry` (integer)
- `is_expiring_soon` (boolean)
- `is_expired` (boolean)

---

### Recipes Domain

#### Recipes

| Method | Endpoint | Action |
|--------|----------|--------|
| GET | `/recipes` | List all recipes |
| GET | `/recipes/:id` | Get single recipe |
| POST | `/recipes` | Create recipe |
| PATCH | `/recipes/:id` | Update recipe |
| DELETE | `/recipes/:id` | Delete recipe |

**Attributes:**
- `name` (string, required)
- `description` (string)
- `instructions` (string)
- `prep_time_minutes` (integer)
- `cook_time_minutes` (integer)
- `servings` (integer, default: 4)
- `difficulty` (enum: easy, medium, hard)
- `image_url` (string)
- `source` (string)
- `is_favorite` (boolean, default: false)

**Calculations (read-only):**
- `total_time_minutes` (integer)
- `ingredient_availability` (decimal, 0-100)
- `can_make` (boolean)
- `missing_ingredients` (array of strings)

---

### Meal Planning Domain

#### Meal Plans

| Method | Endpoint | Action |
|--------|----------|--------|
| GET | `/meal_plans` | List all meal plans |
| GET | `/meal_plans/:id` | Get single plan |
| POST | `/meal_plans` | Create meal plan |
| PATCH | `/meal_plans/:id` | Update meal plan |
| DELETE | `/meal_plans/:id` | Delete meal plan |

**Attributes:**
- `scheduled_date` (date, required)
- `meal_type` (enum: breakfast, lunch, dinner, snack, required)
- `servings` (integer, default: 4)
- `notes` (string)
- `status` (enum: planned, completed, skipped)
- `completed_at` (datetime)
- `recipe_id` (uuid, required)

---

### Shopping Domain

#### Shopping Lists

| Method | Endpoint | Action |
|--------|----------|--------|
| GET | `/shopping_lists` | List all lists |
| GET | `/shopping_lists/:id` | Get single list |
| POST | `/shopping_lists` | Create list |
| PATCH | `/shopping_lists/:id` | Update list |
| DELETE | `/shopping_lists/:id` | Delete list |

**Attributes:**
- `name` (string, default: "Shopping List")
- `status` (enum: active, completed, archived)
- `generated_from` (enum: manual, meal_plan)
- `notes` (string)

**Calculations (read-only):**
- `total_items` (integer)
- `checked_items` (integer)
- `progress_percentage` (integer, 0-100)

---

### Analytics Domain

#### Usage Logs
Track consumption and waste

| Method | Endpoint | Action |
|--------|----------|--------|
| GET | `/usage_logs` | List all logs |
| GET | `/usage_logs/:id` | Get single log |

**Attributes:**
- `quantity` (decimal, required)
- `unit` (string)
- `reason` (enum: consumed, expired, wasted, donated)
- `occurred_at` (datetime)
- `cost` (money)
- `grocery_item_id` (uuid, required)

---

### Notifications Domain

#### Notification Preferences

| Method | Endpoint | Action |
|--------|----------|--------|
| GET | `/notification_preferences` | List preferences |
| GET | `/notification_preferences/:id` | Get preference |
| POST | `/notification_preferences` | Create preference |
| PATCH | `/notification_preferences/:id` | Update preference |
| DELETE | `/notification_preferences/:id` | Delete preference |

**Attributes:**
- `expiration_alerts_enabled` (boolean, default: true)
- `expiration_alert_days` (integer, default: 7)
- `recipe_suggestions_enabled` (boolean, default: true)
- `email_notifications_enabled` (boolean, default: false)
- `in_app_notifications_enabled` (boolean, default: true)

---

## Request/Response Examples

### Create a Grocery Item

```bash
POST /api/json/grocery_items
Authorization: Bearer <token>
Content-Type: application/vnd.api+json

{
  "data": {
    "type": "grocery_item",
    "attributes": {
      "name": "Organic Milk",
      "description": "Whole milk, 1 gallon",
      "default_unit": "gallon"
    }
  }
}
```

**Response (201 Created):**
```json
{
  "data": {
    "type": "grocery_item",
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "attributes": {
      "name": "Organic Milk",
      "description": "Whole milk, 1 gallon",
      "default_unit": "gallon",
      "barcode": null,
      "created_at": "2025-12-16T22:00:00Z",
      "updated_at": "2025-12-16T22:00:00Z"
    },
    "relationships": {
      "category": {
        "data": null
      }
    }
  }
}
```

### List Inventory with Filters

```bash
GET /api/json/inventory_entries?filter[status]=available
Authorization: Bearer <token>
```

### Include Relationships

```bash
GET /api/json/inventory_entries?include=grocery_item,storage_location
Authorization: Bearer <token>
```

---

## Error Responses

All errors follow JSON:API error format:

```json
{
  "errors": [
    {
      "status": "422",
      "title": "Invalid Attribute",
      "detail": "name is required",
      "source": {
        "pointer": "/data/attributes/name"
      }
    }
  ]
}
```

### Common Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Created |
| 204 | No Content (delete) |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 422 | Unprocessable Entity |

---

## Multi-tenancy

All data is scoped to the authenticated user's account. The API automatically sets the tenant based on the user's primary account membership. Users can only access data belonging to their account.

---

## Rate Limiting

Currently no rate limiting is implemented. This may change in future versions.

---

## Versioning

The API does not currently implement versioning. Breaking changes will be announced in advance.
