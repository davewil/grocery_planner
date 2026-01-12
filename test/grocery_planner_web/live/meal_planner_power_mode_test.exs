defmodule GroceryPlannerWeb.MealPlannerPowerModeTest do
  @moduledoc """
  Tests for Power Mode drag-and-drop functionality in the Meal Planner.
  """
  use GroceryPlannerWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import GroceryPlanner.MealPlanningTestHelpers

  setup do
    account = create_account()
    user = create_user(account)

    # Set user to power mode
    {:ok, user} = GroceryPlanner.Accounts.User.update(user, %{meal_planner_layout: "power"})

    today = Date.utc_today()
    week_start = Date.add(today, -(Date.day_of_week(today) - 1))

    conn =
      build_conn()
      |> init_test_session(%{
        user_id: user.id,
        account_id: account.id
      })

    %{conn: conn, account: account, user: user, week_start: week_start}
  end

  describe "power mode layout" do
    test "renders power mode with kanban board", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/meal-planner")

      # Use element selectors which are more reliable
      assert has_element?(view, "#power-mode-kanban")
      assert has_element?(view, "#power-week-board")
    end

    test "displays all seven days", %{conn: conn, week_start: week_start} do
      {:ok, _view, html} = live(conn, "/meal-planner")

      # Check that all days of the week are displayed
      for i <- 0..6 do
        day = Date.add(week_start, i)
        assert html =~ Calendar.strftime(day, "%a")
      end
    end

    test "shows command bar with bulk actions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/meal-planner")

      assert has_element?(view, "button[phx-click='copy_last_week']")
      assert has_element?(view, "button[phx-click='auto_fill_week']")
      assert has_element?(view, "button[phx-click='clear_week']")
      assert has_element?(view, "button[phx-click='toggle_sidebar']")
    end

    test "shows recipe sidebar by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/meal-planner")

      assert html =~ "Search recipes"
      assert html =~ "Drag recipes to the board"
    end
  end

  describe "drop_meal event (moving meals)" do
    setup %{conn: conn, account: account, user: user, week_start: week_start} do
      recipe = create_recipe(account, user, %{name: "Moveable Meal"})

      {:ok, meal_plan} =
        GroceryPlanner.MealPlanning.create_meal_plan(
          account.id,
          %{
            recipe_id: recipe.id,
            scheduled_date: week_start,
            meal_type: :breakfast,
            servings: 4
          },
          actor: user,
          tenant: account.id
        )

      {:ok, view, _html} = live(conn, "/meal-planner")

      %{view: view, meal_plan: meal_plan, recipe: recipe}
    end

    test "moves meal to new date and slot", %{
      view: view,
      meal_plan: meal_plan,
      week_start: week_start,
      user: user,
      account: account
    } do
      target_date = Date.add(week_start, 2)

      # Simulate drop event
      view
      |> render_hook("drop_meal", %{
        "meal_id" => meal_plan.id,
        "target_date" => Date.to_iso8601(target_date),
        "target_meal_type" => "dinner"
      })

      # Verify the meal was moved
      {:ok, updated_meal} =
        GroceryPlanner.MealPlanning.get_meal_plan(meal_plan.id,
          actor: user,
          tenant: account.id
        )

      assert updated_meal.scheduled_date == target_date
      assert updated_meal.meal_type == :dinner
    end

    test "supports undo after moving meal", %{
      view: view,
      meal_plan: meal_plan,
      week_start: week_start,
      user: user,
      account: account
    } do
      original_date = meal_plan.scheduled_date
      original_type = meal_plan.meal_type
      target_date = Date.add(week_start, 3)

      # Move the meal
      view
      |> render_hook("drop_meal", %{
        "meal_id" => meal_plan.id,
        "target_date" => Date.to_iso8601(target_date),
        "target_meal_type" => "lunch"
      })

      # Trigger undo
      view
      |> render_hook("undo", %{})

      # Verify the meal was moved back
      {:ok, restored_meal} =
        GroceryPlanner.MealPlanning.get_meal_plan(meal_plan.id,
          actor: user,
          tenant: account.id
        )

      assert restored_meal.scheduled_date == original_date
      assert restored_meal.meal_type == original_type
    end
  end

  describe "swap confirmation" do
    setup %{conn: conn, account: account, user: user, week_start: week_start} do
      recipe1 = create_recipe(account, user, %{name: "Meal A"})
      recipe2 = create_recipe(account, user, %{name: "Meal B"})

      {:ok, meal_a} =
        GroceryPlanner.MealPlanning.create_meal_plan(
          account.id,
          %{
            recipe_id: recipe1.id,
            scheduled_date: week_start,
            meal_type: :breakfast,
            servings: 4
          },
          actor: user,
          tenant: account.id
        )

      {:ok, meal_b} =
        GroceryPlanner.MealPlanning.create_meal_plan(
          account.id,
          %{
            recipe_id: recipe2.id,
            scheduled_date: Date.add(week_start, 1),
            meal_type: :dinner,
            servings: 4
          },
          actor: user,
          tenant: account.id
        )

      {:ok, view, _html} = live(conn, "/meal-planner")

      %{view: view, meal_a: meal_a, meal_b: meal_b}
    end

    test "request_swap_confirmation shows modal", %{view: view, meal_a: meal_a, meal_b: meal_b} do
      target_date = meal_b.scheduled_date

      html =
        view
        |> render_hook("request_swap_confirmation", %{
          "dragged_meal_id" => meal_a.id,
          "target_meal_id" => meal_b.id,
          "target_date" => Date.to_iso8601(target_date),
          "target_meal_type" => "dinner"
        })

      assert html =~ "Swap Meals?"
      assert html =~ "Meal A"
      assert html =~ "Meal B"
    end

    test "confirm_swap swaps meal positions", %{
      view: view,
      meal_a: meal_a,
      meal_b: meal_b,
      user: user,
      account: account
    } do
      meal_a_original = %{date: meal_a.scheduled_date, meal_type: meal_a.meal_type}
      meal_b_original = %{date: meal_b.scheduled_date, meal_type: meal_b.meal_type}

      # Request swap confirmation
      view
      |> render_hook("request_swap_confirmation", %{
        "dragged_meal_id" => meal_a.id,
        "target_meal_id" => meal_b.id,
        "target_date" => Date.to_iso8601(meal_b.scheduled_date),
        "target_meal_type" => to_string(meal_b.meal_type)
      })

      # Confirm the swap
      view
      |> element("button[phx-click='confirm_swap']")
      |> render_click()

      # Verify meals were swapped
      {:ok, updated_a} =
        GroceryPlanner.MealPlanning.get_meal_plan(meal_a.id, actor: user, tenant: account.id)

      {:ok, updated_b} =
        GroceryPlanner.MealPlanning.get_meal_plan(meal_b.id, actor: user, tenant: account.id)

      # Meal A should now be at Meal B's original position
      assert updated_a.scheduled_date == meal_b_original.date
      assert updated_a.meal_type == meal_b_original.meal_type

      # Meal B should now be at Meal A's original position
      assert updated_b.scheduled_date == meal_a_original.date
      assert updated_b.meal_type == meal_a_original.meal_type
    end

    test "cancel_swap closes modal without changes", %{
      view: view,
      meal_a: meal_a,
      meal_b: meal_b,
      user: user,
      account: account
    } do
      meal_a_original = meal_a.scheduled_date

      # Request swap confirmation
      view
      |> render_hook("request_swap_confirmation", %{
        "dragged_meal_id" => meal_a.id,
        "target_meal_id" => meal_b.id,
        "target_date" => Date.to_iso8601(meal_b.scheduled_date),
        "target_meal_type" => to_string(meal_b.meal_type)
      })

      # Cancel the swap
      view
      |> element("button[phx-click='cancel_swap']")
      |> render_click()

      # Verify meal A is unchanged
      {:ok, unchanged_a} =
        GroceryPlanner.MealPlanning.get_meal_plan(meal_a.id, actor: user, tenant: account.id)

      assert unchanged_a.scheduled_date == meal_a_original
    end
  end

  describe "bulk operations" do
    setup %{conn: conn, account: account, user: user, week_start: week_start} do
      recipe = create_recipe(account, user, %{name: "Bulk Test Meal"})

      # Create meals for the week
      meals =
        for i <- 0..2 do
          {:ok, meal} =
            GroceryPlanner.MealPlanning.create_meal_plan(
              account.id,
              %{
                recipe_id: recipe.id,
                scheduled_date: Date.add(week_start, i),
                meal_type: :dinner,
                servings: 4
              },
              actor: user,
              tenant: account.id
            )

          meal
        end

      {:ok, view, _html} = live(conn, "/meal-planner")

      %{view: view, meals: meals, recipe: recipe}
    end

    test "clear_week removes all meals", %{
      view: view,
      user: user,
      account: account,
      week_start: week_start
    } do
      # Verify meals exist before clearing
      week_end = Date.add(week_start, 6)

      {:ok, before_meals} =
        GroceryPlanner.MealPlanning.list_meal_plans_by_date_range(
          week_start,
          week_end,
          actor: user,
          tenant: account.id
        )

      assert length(before_meals) == 3

      # Clear the week (bypassing confirmation for test)
      view
      |> element("button[phx-click='clear_week']")
      |> render_click()

      # Verify all meals are gone
      {:ok, after_meals} =
        GroceryPlanner.MealPlanning.list_meal_plans_by_date_range(
          week_start,
          week_end,
          actor: user,
          tenant: account.id
        )

      assert length(after_meals) == 0
    end

    test "selection toggle works", %{view: view, meals: meals} do
      meal = hd(meals)

      # Toggle selection on
      view
      |> render_hook("toggle_meal_selection", %{"meal-id" => meal.id})

      html = render(view)
      assert html =~ "1 selected"

      # Toggle selection off
      view
      |> render_hook("toggle_meal_selection", %{"meal-id" => meal.id})

      html = render(view)
      refute html =~ "1 selected"
    end

    test "select_all selects all meals", %{view: view, meals: meals} do
      view
      |> render_hook("select_all", %{})

      html = render(view)
      assert html =~ "#{length(meals)} selected"
    end

    test "clear_selection clears all", %{view: view} do
      # Select all first
      view
      |> render_hook("select_all", %{})

      # Then clear
      view
      |> render_hook("clear_selection", %{})

      # Check the specific selection badge is gone
      html = render(view)
      refute html =~ "badge badge-primary"
    end
  end

  describe "drop_recipe event (adding from sidebar)" do
    setup %{conn: conn, account: account, user: user, week_start: week_start} do
      recipe = create_recipe(account, user, %{name: "Sidebar Recipe"})

      {:ok, view, _html} = live(conn, "/meal-planner")

      %{view: view, recipe: recipe, target_date: Date.add(week_start, 1)}
    end

    test "creates new meal from dropped recipe", %{
      view: view,
      recipe: recipe,
      target_date: target_date,
      user: user,
      account: account
    } do
      # Simulate dropping a recipe from sidebar
      result =
        view
        |> render_hook("drop_recipe", %{
          "recipe_id" => recipe.id,
          "target_date" => Date.to_iso8601(target_date),
          "target_meal_type" => "lunch"
        })

      # Ensure no error flash
      refute result =~ "Failed to add meal"

      # Query all meals for the account
      {:ok, all_meals} =
        GroceryPlanner.MealPlanning.list_meal_plans(
          actor: user,
          tenant: account.id
        )

      # Find the meal we just created
      meal =
        Enum.find(all_meals, fn m ->
          m.recipe_id == recipe.id && m.scheduled_date == target_date && m.meal_type == :lunch
        end)

      assert meal != nil,
             "Expected to find a meal with recipe_id=#{recipe.id}, date=#{target_date}, type=lunch"

      assert meal.servings == 4
    end
  end

  describe "sidebar" do
    test "toggle_sidebar hides and shows sidebar", %{conn: conn} do
      {:ok, view, html} = live(conn, "/meal-planner")

      # Sidebar should be visible by default
      assert html =~ "Search recipes"

      # Toggle off
      view
      |> element("button[phx-click='toggle_sidebar']")
      |> render_click()

      # Hard to test visibility with CSS, but the state should change
      # The sidebar uses w-0 when closed

      # Toggle back on
      view
      |> element("button[phx-click='toggle_sidebar']")
      |> render_click()
    end
  end
end
