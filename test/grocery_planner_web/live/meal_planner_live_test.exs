defmodule GroceryPlannerWeb.MealPlannerLiveTest do
  use GroceryPlannerWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import GroceryPlanner.MealPlanningTestHelpers

  setup do
    account = create_account()
    user = create_user(account)

    {:ok, user} = GroceryPlanner.Accounts.User.update(user, %{meal_planner_layout: "focus"})

    conn =
      build_conn()
      |> init_test_session(%{
        user_id: user.id,
        account_id: account.id
      })

    %{conn: conn, account: account, user: user}
  end

  describe "mount and navigation" do
    test "requires authentication", %{conn: conn} do
      conn = delete_session(conn, :user_id)

      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, "/meal-planner")
    end

    test "renders meal planner page for authenticated user", %{conn: conn} do
      {:ok, view, html} = live(conn, "/meal-planner")

      assert html =~ "Meal Planner"
      assert html =~ "Plan your weekly meals with ease"
      assert html =~ "Layout"
      assert html =~ "Focus"
      assert has_element?(view, "a[href='/settings']", "Change")
      assert has_element?(view, "button[phx-click='prev_week']")
      assert has_element?(view, "button[phx-click='today']", "Today")
      assert has_element?(view, "button[phx-click='next_week']")
    end

    test "displays current week by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/meal-planner")

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      week_end = Date.add(week_start, 6)

      assert html =~ Calendar.strftime(week_start, "%B %d")
      assert html =~ Calendar.strftime(week_end, "%B %d, %Y")
    end
  end

  describe "viewing meals" do
    test "displays meals for the week", %{conn: conn, account: account, user: user} do
      recipe = create_recipe(account, user, %{name: "Test Meal"})

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      tuesday = Date.add(week_start, 1)

      create_meal_plan(account, user, recipe, %{
        scheduled_date: tuesday,
        meal_type: :breakfast,
        servings: 4
      })

      {:ok, view, html} = live(conn, "/meal-planner")

      assert html =~ "Test Meal"
      assert has_element?(view, "button[phx-click='select_day'][phx-value-date='#{tuesday}']")
    end

    test "selecting a day shows meal details", %{conn: conn, account: account, user: user} do
      recipe = create_recipe(account, user, %{name: "Breakfast Delight"})

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      tuesday = Date.add(week_start, 1)

      create_meal_plan(account, user, recipe, %{
        scheduled_date: tuesday,
        meal_type: :breakfast,
        servings: 6
      })

      {:ok, view, _html} = live(conn, "/meal-planner")

      html =
        view
        |> element("button[phx-click='select_day'][phx-value-date='#{tuesday}']")
        |> render_click()

      assert html =~ "Tuesday"
      assert html =~ "Breakfast Delight"
      assert html =~ "6 servings"
      assert has_element?(view, "button[phx-click='edit_meal']")
      assert has_element?(view, "button[phx-click='remove_meal']")
    end
  end

  describe "editing meals" do
    test "opens edit modal when clicking edit button", %{conn: conn, account: account, user: user} do
      recipe = create_recipe(account, user, %{name: "Pasta Carbonara"})

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      tuesday = Date.add(week_start, 1)

      meal_plan =
        create_meal_plan(account, user, recipe, %{
          scheduled_date: tuesday,
          meal_type: :dinner,
          servings: 4
        })

      {:ok, view, _html} = live(conn, "/meal-planner")

      view
      |> element("button[phx-click='select_day'][phx-value-date='#{tuesday}']")
      |> render_click()

      html =
        view
        |> element("button[phx-click='edit_meal'][phx-value-id='#{meal_plan.id}']")
        |> render_click()

      assert html =~ "Edit Meal"
      assert html =~ "Pasta Carbonara"
      assert has_element?(view, "#edit-meal-form")
      assert has_element?(view, "#edit-servings")
      assert has_element?(view, "#edit-notes")
      assert has_element?(view, "button[type='submit']", "Save Changes")
    end

    test "edit modal displays current servings value", %{
      conn: conn,
      account: account,
      user: user
    } do
      recipe = create_recipe(account, user, %{name: "Chicken Curry"})

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      tuesday = Date.add(week_start, 1)

      meal_plan =
        create_meal_plan(account, user, recipe, %{
          scheduled_date: tuesday,
          meal_type: :lunch,
          servings: 8
        })

      {:ok, view, _html} = live(conn, "/meal-planner")

      view
      |> element("button[phx-click='select_day'][phx-value-date='#{tuesday}']")
      |> render_click()

      view
      |> element("button[phx-click='edit_meal'][phx-value-id='#{meal_plan.id}']")
      |> render_click()

      assert has_element?(view, "#edit-servings[value='8']")
    end

    test "edit modal displays current notes value", %{conn: conn, account: account, user: user} do
      recipe = create_recipe(account, user, %{name: "Vegetable Stir Fry"})

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      tuesday = Date.add(week_start, 1)

      meal_plan =
        create_meal_plan(account, user, recipe, %{
          scheduled_date: tuesday,
          meal_type: :dinner,
          servings: 4,
          notes: "Extra spicy please"
        })

      {:ok, view, _html} = live(conn, "/meal-planner")

      view
      |> element("button[phx-click='select_day'][phx-value-date='#{tuesday}']")
      |> render_click()

      html =
        view
        |> element("button[phx-click='edit_meal'][phx-value-id='#{meal_plan.id}']")
        |> render_click()

      assert html =~ "Extra spicy please"
    end

    test "updates meal servings successfully", %{conn: conn, account: account, user: user} do
      recipe = create_recipe(account, user, %{name: "Salmon Teriyaki"})

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      tuesday = Date.add(week_start, 1)

      meal_plan =
        create_meal_plan(account, user, recipe, %{
          scheduled_date: tuesday,
          meal_type: :dinner,
          servings: 4
        })

      {:ok, view, _html} = live(conn, "/meal-planner")

      view
      |> element("button[phx-click='select_day'][phx-value-date='#{tuesday}']")
      |> render_click()

      view
      |> element("button[phx-click='edit_meal'][phx-value-id='#{meal_plan.id}']")
      |> render_click()

      html =
        view
        |> form("#edit-meal-form", %{servings: "8", notes: ""})
        |> render_submit()

      assert html =~ "Meal updated successfully"
      assert html =~ "8 servings"

      updated_meal_plan =
        Ash.get!(GroceryPlanner.MealPlanning.MealPlan, meal_plan.id,
          actor: user,
          tenant: account.id
        )

      assert updated_meal_plan.servings == 8
    end

    test "updates meal notes successfully", %{conn: conn, account: account, user: user} do
      recipe = create_recipe(account, user, %{name: "Beef Tacos"})

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      tuesday = Date.add(week_start, 1)

      meal_plan =
        create_meal_plan(account, user, recipe, %{
          scheduled_date: tuesday,
          meal_type: :dinner,
          servings: 4
        })

      {:ok, view, _html} = live(conn, "/meal-planner")

      view
      |> element("button[phx-click='select_day'][phx-value-date='#{tuesday}']")
      |> render_click()

      view
      |> element("button[phx-click='edit_meal'][phx-value-id='#{meal_plan.id}']")
      |> render_click()

      html =
        view
        |> form("#edit-meal-form", %{servings: "4", notes: "Add extra cheese"})
        |> render_submit()

      assert html =~ "Meal updated successfully"

      updated_meal_plan =
        Ash.get!(GroceryPlanner.MealPlanning.MealPlan, meal_plan.id,
          actor: user,
          tenant: account.id
        )

      assert updated_meal_plan.notes == "Add extra cheese"
    end

    test "updates both servings and notes together", %{conn: conn, account: account, user: user} do
      recipe = create_recipe(account, user, %{name: "Greek Salad"})

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      tuesday = Date.add(week_start, 1)

      meal_plan =
        create_meal_plan(account, user, recipe, %{
          scheduled_date: tuesday,
          meal_type: :lunch,
          servings: 2
        })

      {:ok, view, _html} = live(conn, "/meal-planner")

      view
      |> element("button[phx-click='select_day'][phx-value-date='#{tuesday}']")
      |> render_click()

      view
      |> element("button[phx-click='edit_meal'][phx-value-id='#{meal_plan.id}']")
      |> render_click()

      html =
        view
        |> form("#edit-meal-form", %{servings: "6", notes: "Make it large portions"})
        |> render_submit()

      assert html =~ "Meal updated successfully"
      assert html =~ "6 servings"

      updated_meal_plan =
        Ash.get!(GroceryPlanner.MealPlanning.MealPlan, meal_plan.id,
          actor: user,
          tenant: account.id
        )

      assert updated_meal_plan.servings == 6
      assert updated_meal_plan.notes == "Make it large portions"
    end

    test "closes modal after successful update", %{conn: conn, account: account, user: user} do
      recipe = create_recipe(account, user, %{name: "Pizza Margherita"})

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      tuesday = Date.add(week_start, 1)

      meal_plan =
        create_meal_plan(account, user, recipe, %{
          scheduled_date: tuesday,
          meal_type: :dinner,
          servings: 4
        })

      {:ok, view, _html} = live(conn, "/meal-planner")

      view
      |> element("button[phx-click='select_day'][phx-value-date='#{tuesday}']")
      |> render_click()

      view
      |> element("button[phx-click='edit_meal'][phx-value-id='#{meal_plan.id}']")
      |> render_click()

      assert has_element?(view, "#edit-meal-modal-backdrop")

      view
      |> form("#edit-meal-form", %{servings: "8", notes: ""})
      |> render_submit()

      refute has_element?(view, "#edit-meal-modal-backdrop")
    end

    test "closes modal when clicking cancel button", %{
      conn: conn,
      account: account,
      user: user
    } do
      recipe = create_recipe(account, user, %{name: "Mushroom Risotto"})

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      tuesday = Date.add(week_start, 1)

      meal_plan =
        create_meal_plan(account, user, recipe, %{
          scheduled_date: tuesday,
          meal_type: :dinner,
          servings: 4
        })

      {:ok, view, _html} = live(conn, "/meal-planner")

      view
      |> element("button[phx-click='select_day'][phx-value-date='#{tuesday}']")
      |> render_click()

      view
      |> element("button[phx-click='edit_meal'][phx-value-id='#{meal_plan.id}']")
      |> render_click()

      assert has_element?(view, "#edit-meal-modal-backdrop")

      view
      |> element("button[phx-click='close_edit_modal']", "Cancel")
      |> render_click()

      refute has_element?(view, "#edit-meal-modal-backdrop")
    end

    test "validates servings is a positive number", %{
      conn: conn,
      account: account,
      user: user
    } do
      recipe = create_recipe(account, user, %{name: "Chocolate Cake"})

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      tuesday = Date.add(week_start, 1)

      meal_plan =
        create_meal_plan(account, user, recipe, %{
          scheduled_date: tuesday,
          meal_type: :snack,
          servings: 4
        })

      {:ok, view, _html} = live(conn, "/meal-planner")

      view
      |> element("button[phx-click='select_day'][phx-value-date='#{tuesday}']")
      |> render_click()

      view
      |> element("button[phx-click='edit_meal'][phx-value-id='#{meal_plan.id}']")
      |> render_click()

      assert has_element?(view, "#edit-servings[min='1']")
      assert has_element?(view, "#edit-servings[required]")
    end
  end

  describe "removing meals" do
    test "removes meal when clicking remove button", %{conn: conn, account: account, user: user} do
      recipe = create_recipe(account, user, %{name: "Burger and Fries"})

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      tuesday = Date.add(week_start, 1)

      meal_plan =
        create_meal_plan(account, user, recipe, %{
          scheduled_date: tuesday,
          meal_type: :lunch,
          servings: 2
        })

      {:ok, view, _html} = live(conn, "/meal-planner")

      view
      |> element("button[phx-click='select_day'][phx-value-date='#{tuesday}']")
      |> render_click()

      html =
        view
        |> element("button[phx-click='remove_meal'][phx-value-id='#{meal_plan.id}']")
        |> render_click()

      assert html =~ "Meal removed successfully"
      refute html =~ "Burger and Fries"
    end
  end

  describe "chain suggestion" do
    test "shows chain suggestion modal after adding a base recipe", %{
      conn: conn,
      account: account,
      user: user
    } do
      base = create_recipe(account, user, %{name: "Roast Chicken", is_base_recipe: true})

      _follow_up =
        create_recipe(account, user, %{
          name: "Chicken Fried Rice",
          is_follow_up: true,
          parent_recipe_id: base.id
        })

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      tuesday = Date.add(week_start, 1)

      {:ok, view, _html} = live(conn, "/meal-planner")

      view
      |> element("button[phx-click='select_day'][phx-value-date='#{tuesday}']")
      |> render_click()

      view
      |> element(
        "button[phx-click='add_meal'][phx-value-date='#{tuesday}'][phx-value-meal_type='lunch']"
      )
      |> render_click()

      html =
        view
        |> element("button[phx-click='select_recipe'][phx-value-id='#{base.id}']")
        |> render_click()

      assert html =~ "Use Those Leftovers!"
      assert html =~ "Roast Chicken"
      assert html =~ "Chicken Fried Rice"
      assert has_element?(view, "#chain-suggestion-modal-backdrop")
    end

    test "does not show chain suggestion modal if all candidate slots are occupied", %{
      conn: conn,
      account: account,
      user: user
    } do
      base = create_recipe(account, user, %{name: "Roast Chicken", is_base_recipe: true})

      _follow_up =
        create_recipe(account, user, %{
          name: "Chicken Soup",
          is_follow_up: true,
          parent_recipe_id: base.id
        })

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      tuesday = Date.add(week_start, 1)

      occupy_recipe = create_recipe(account, user, %{name: "Other"})

      create_meal_plan(account, user, occupy_recipe, %{
        scheduled_date: tuesday,
        meal_type: :dinner,
        servings: 2
      })

      create_meal_plan(account, user, occupy_recipe, %{
        scheduled_date: Date.add(tuesday, 1),
        meal_type: :lunch,
        servings: 2
      })

      create_meal_plan(account, user, occupy_recipe, %{
        scheduled_date: Date.add(tuesday, 1),
        meal_type: :dinner,
        servings: 2
      })

      {:ok, view, _html} = live(conn, "/meal-planner")

      view
      |> element("button[phx-click='select_day'][phx-value-date='#{tuesday}']")
      |> render_click()

      view
      |> element(
        "button[phx-click='add_meal'][phx-value-date='#{tuesday}'][phx-value-meal_type='lunch']"
      )
      |> render_click()

      html =
        view
        |> element("button[phx-click='select_recipe'][phx-value-id='#{base.id}']")
        |> render_click()

      refute html =~ "Use Those Leftovers!"
      refute has_element?(view, "#chain-suggestion-modal-backdrop")
    end

    test "accepting chain suggestion creates follow-up meal plan", %{
      conn: conn,
      account: account,
      user: user
    } do
      base = create_recipe(account, user, %{name: "Roast Chicken", is_base_recipe: true})

      follow_up =
        create_recipe(account, user, %{
          name: "Chicken Soup",
          is_follow_up: true,
          parent_recipe_id: base.id
        })

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      tuesday = Date.add(week_start, 1)

      {:ok, view, _html} = live(conn, "/meal-planner")

      view
      |> element("button[phx-click='select_day'][phx-value-date='#{tuesday}']")
      |> render_click()

      view
      |> element(
        "button[phx-click='add_meal'][phx-value-date='#{tuesday}'][phx-value-meal_type='lunch']"
      )
      |> render_click()

      view
      |> element("button[phx-click='select_recipe'][phx-value-id='#{base.id}']")
      |> render_click()

      view
      |> element("button[phx-click='accept_chain_suggestion']")
      |> render_click()

      {:ok, meal_plans} =
        GroceryPlanner.MealPlanning.list_meal_plans(
          actor: user,
          tenant: account.id,
          query: GroceryPlanner.MealPlanning.MealPlan |> Ash.Query.sort(scheduled_date: :asc)
        )

      assert Enum.any?(meal_plans, fn mp -> mp.recipe_id == follow_up.id end)
    end
  end

  describe "week navigation" do
    test "navigates to next week", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/meal-planner")

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      next_week_start = Date.add(week_start, 7)

      html =
        view
        |> element("button[phx-click='next_week']")
        |> render_click()

      assert html =~ Calendar.strftime(next_week_start, "%B %d")
    end

    test "navigates to previous week", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/meal-planner")

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))
      prev_week_start = Date.add(week_start, -7)

      html =
        view
        |> element("button[phx-click='prev_week']")
        |> render_click()

      assert html =~ Calendar.strftime(prev_week_start, "%B %d")
    end

    test "navigates back to current week with Today button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/meal-planner")

      today = Date.utc_today()
      week_start = Date.add(today, -(Date.day_of_week(today) - 1))

      view
      |> element("button[phx-click='next_week']")
      |> render_click()

      html =
        view
        |> element("button[phx-click='today']")
        |> render_click()

      assert html =~ Calendar.strftime(week_start, "%B %d")
    end
  end
end
