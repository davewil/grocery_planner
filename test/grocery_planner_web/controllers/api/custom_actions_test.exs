defmodule GroceryPlannerWeb.Api.CustomActionsTest do
  @moduledoc """
  Behavioral tests for custom action endpoints (US-004).

  Tests:
  - POST /api/json/shopping_lists/generate_from_meal_plans
  - POST /api/json/shopping_lists/:shopping_list_id/items/:id/add_to_inventory
  - PATCH /api/json/meal_plans/:id/complete
  """
  use GroceryPlannerWeb.ConnCase, async: true
  alias GroceryPlanner.ShoppingTestHelpers
  alias GroceryPlanner.MealPlanningTestHelpers
  alias GroceryPlanner.InventoryTestHelpers

  describe "POST /api/json/shopping_lists/generate_from_meal_plans" do
    setup do
      {account, user} = ShoppingTestHelpers.create_account_and_user()
      token = Phoenix.Token.sign(GroceryPlannerWeb.Endpoint, "user auth", user.id)
      recipe = MealPlanningTestHelpers.create_recipe(account, user)
      %{account: account, user: user, token: token, recipe: recipe}
    end

    test "generates shopping list from meal plans", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      recipe: recipe
    } do
      # Create a meal plan for next week
      start_date = Date.add(Date.utc_today(), 7)

      _meal_plan =
        MealPlanningTestHelpers.create_meal_plan(account, user, recipe, %{
          scheduled_date: start_date
        })

      payload = %{
        "data" => %{
          "type" => "shopping_list",
          "attributes" => %{
            "account_id" => account.id,
            "name" => "Weekly Shopping List",
            "start_date" => to_string(start_date),
            "end_date" => to_string(Date.add(start_date, 7))
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/shopping_lists/generate_from_meal_plans", payload)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["type"] == "shopping_list"
      assert data["attributes"]["name"] == "Weekly Shopping List"
      assert data["attributes"]["generated_from"] == "meal_plan"
    end

    test "returns 401 without authentication", %{conn: conn} do
      payload = %{
        "data" => %{
          "type" => "shopping_list",
          "attributes" => %{
            "name" => "Test",
            "start_date" => to_string(Date.utc_today()),
            "end_date" => to_string(Date.add(Date.utc_today(), 7))
          }
        }
      }

      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/shopping_lists/generate_from_meal_plans", payload)

      assert json_response(conn, 401)
    end

    test "returns validation error when dates are missing", %{conn: conn, token: token} do
      payload = %{
        "data" => %{
          "type" => "shopping_list",
          "attributes" => %{
            "name" => "Test"
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/shopping_lists/generate_from_meal_plans", payload)

      assert %{"errors" => errors} = json_response(conn, 400)
      assert length(errors) > 0
    end
  end

  describe "POST /api/json/shopping_lists/:shopping_list_id/items/:id/add_to_inventory" do
    setup do
      {account, user} = ShoppingTestHelpers.create_account_and_user()
      token = Phoenix.Token.sign(GroceryPlannerWeb.Endpoint, "user auth", user.id)
      shopping_list = ShoppingTestHelpers.create_shopping_list(account, user)
      grocery_item = InventoryTestHelpers.create_grocery_item(account, user, %{name: "Milk"})

      storage_location =
        InventoryTestHelpers.create_storage_location(account, user, %{name: "Refrigerator"})

      %{
        account: account,
        user: user,
        token: token,
        shopping_list: shopping_list,
        grocery_item: grocery_item,
        storage_location: storage_location
      }
    end

    test "adds shopping list item to inventory", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      shopping_list: shopping_list,
      grocery_item: grocery_item,
      storage_location: storage_location
    } do
      # Create a shopping list item linked to a grocery item
      item =
        ShoppingTestHelpers.create_shopping_list_item(account, user, shopping_list, %{
          name: "Milk",
          grocery_item_id: grocery_item.id,
          quantity: Decimal.new("2"),
          unit: "liters"
        })

      payload = %{
        "data" => %{
          "type" => "shopping_list_item",
          "id" => item.id,
          "attributes" => %{
            "storage_location_id" => storage_location.id,
            "purchase_date" => to_string(Date.utc_today())
          }
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch(
          "/api/json/shopping_lists/#{shopping_list.id}/items/#{item.id}/add_to_inventory",
          payload
        )

      assert %{"data" => data} = json_response(conn, 200)
      assert data["type"] == "shopping_list_item"

      # Verify inventory entry was created
      {:ok, entries} =
        GroceryPlanner.Inventory.list_inventory_entries_filtered(
          %{status: :available},
          actor: user,
          tenant: account.id
        )

      assert length(entries) == 1
      entry = hd(entries)
      assert entry.grocery_item_id == grocery_item.id
      assert Decimal.equal?(entry.quantity, Decimal.new("2"))
      assert entry.unit == "liters"
    end

    test "returns error when item is not linked to grocery item", %{
      conn: conn,
      token: token,
      account: account,
      user: user,
      shopping_list: shopping_list
    } do
      # Create item without grocery_item_id
      item =
        ShoppingTestHelpers.create_shopping_list_item(account, user, shopping_list, %{
          name: "Generic Item",
          grocery_item_id: nil
        })

      payload = %{
        "data" => %{
          "type" => "shopping_list_item",
          "id" => item.id,
          "attributes" => %{}
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch(
          "/api/json/shopping_lists/#{shopping_list.id}/items/#{item.id}/add_to_inventory",
          payload
        )

      assert %{"errors" => errors} = json_response(conn, 400)
      assert length(errors) > 0
    end

    test "returns 401 without authentication", %{
      conn: conn,
      account: account,
      user: user,
      shopping_list: shopping_list,
      grocery_item: grocery_item
    } do
      item =
        ShoppingTestHelpers.create_shopping_list_item(account, user, shopping_list, %{
          grocery_item_id: grocery_item.id
        })

      payload = %{
        "data" => %{
          "type" => "shopping_list_item",
          "id" => item.id,
          "attributes" => %{}
        }
      }

      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch(
          "/api/json/shopping_lists/#{shopping_list.id}/items/#{item.id}/add_to_inventory",
          payload
        )

      assert json_response(conn, 401)
    end

    test "returns 403 when accessing another account's item", %{
      conn: conn,
      token: token
    } do
      {other_account, other_user} = ShoppingTestHelpers.create_account_and_user()
      other_list = ShoppingTestHelpers.create_shopping_list(other_account, other_user)
      other_grocery_item = InventoryTestHelpers.create_grocery_item(other_account, other_user)

      other_item =
        ShoppingTestHelpers.create_shopping_list_item(other_account, other_user, other_list, %{
          grocery_item_id: other_grocery_item.id
        })

      payload = %{
        "data" => %{
          "type" => "shopping_list_item",
          "id" => other_item.id,
          "attributes" => %{}
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post(
          "/api/json/shopping_lists/#{other_list.id}/items/#{other_item.id}/add_to_inventory",
          payload
        )

      assert conn.status in [403, 404]
    end
  end

  describe "PATCH /api/json/meal_plans/:id/complete" do
    setup do
      {account, user} = ShoppingTestHelpers.create_account_and_user()
      token = Phoenix.Token.sign(GroceryPlannerWeb.Endpoint, "user auth", user.id)
      recipe = MealPlanningTestHelpers.create_recipe(account, user)
      meal_plan = MealPlanningTestHelpers.create_meal_plan(account, user, recipe)
      %{account: account, user: user, token: token, meal_plan: meal_plan}
    end

    test "marks meal plan as complete", %{
      conn: conn,
      token: token,
      meal_plan: meal_plan
    } do
      payload = %{
        "data" => %{
          "type" => "meal_plan",
          "id" => meal_plan.id,
          "attributes" => %{}
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/meal_plans/#{meal_plan.id}/complete", payload)

      assert %{"data" => data} = json_response(conn, 200)
      assert data["type"] == "meal_plan"
      assert data["attributes"]["status"] == "completed"
      assert data["attributes"]["completed_at"] != nil
    end

    test "returns 401 without authentication", %{conn: conn, meal_plan: meal_plan} do
      payload = %{
        "data" => %{
          "type" => "meal_plan",
          "id" => meal_plan.id,
          "attributes" => %{}
        }
      }

      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/meal_plans/#{meal_plan.id}/complete", payload)

      assert json_response(conn, 401)
    end

    test "returns 403 when completing another account's meal plan", %{
      conn: conn,
      token: token
    } do
      {other_account, other_user} = ShoppingTestHelpers.create_account_and_user()
      other_recipe = MealPlanningTestHelpers.create_recipe(other_account, other_user)

      other_meal_plan =
        MealPlanningTestHelpers.create_meal_plan(other_account, other_user, other_recipe)

      payload = %{
        "data" => %{
          "type" => "meal_plan",
          "id" => other_meal_plan.id,
          "attributes" => %{}
        }
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/meal_plans/#{other_meal_plan.id}/complete", payload)

      assert conn.status in [403, 404]
    end
  end
end
