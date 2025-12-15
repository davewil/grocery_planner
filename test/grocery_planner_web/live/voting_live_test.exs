defmodule GroceryPlannerWeb.VotingLiveTest do
  use GroceryPlannerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  require Ash.Query

  alias GroceryPlanner.Accounts.{Account, User, AccountMembership}
  alias GroceryPlanner.Recipes.Recipe
  alias GroceryPlanner.MealPlanning.{MealPlanVoteSession, MealPlanVoteEntry}

  setup do
    {:ok, account} =
      Account
      |> Ash.Changeset.for_create(:create, %{name: "Test Household"})
      |> Ash.create()

    {:ok, user} =
      User
      |> Ash.Changeset.for_create(:create, %{
        email: "voter@example.com",
        name: "Voter User",
        password: "password123"
      })
      |> Ash.create()

    {:ok, _membership} =
      AccountMembership
      |> Ash.Changeset.for_create(:create, %{
        account_id: account.id,
        user_id: user.id,
        role: :admin
      })
      |> Ash.create(authorize?: false)

    {:ok, recipe1} =
      Recipe
      |> Ash.Changeset.for_create(:create, %{
        name: "Spaghetti Carbonara",
        account_id: account.id,
        is_favorite: true
      })
      |> Ash.create(actor: user, tenant: account.id)

    {:ok, recipe2} =
      Recipe
      |> Ash.Changeset.for_create(:create, %{
        name: "Chicken Tikka Masala",
        account_id: account.id,
        is_favorite: true
      })
      |> Ash.create(actor: user, tenant: account.id)

    {:ok, recipe3} =
      Recipe
      |> Ash.Changeset.for_create(:create, %{
        name: "Beef Tacos",
        account_id: account.id,
        is_favorite: false
      })
      |> Ash.create(actor: user, tenant: account.id)

    conn =
      build_conn()
      |> init_test_session(%{})
      |> put_session(:user_id, user.id)
      |> assign(:current_user, user)
      |> assign(:current_account, account)

    %{
      conn: conn,
      account: account,
      user: user,
      recipe1: recipe1,
      recipe2: recipe2,
      recipe3: recipe3
    }
  end

  describe "voting page" do
    test "displays favorite recipes", %{conn: conn, recipe1: recipe1, recipe2: recipe2} do
      {:ok, _view, html} = live(conn, ~p"/voting")

      assert html =~ "Meal Planner Voting"
      assert html =~ recipe1.name
      assert html =~ recipe2.name
    end

    test "does not display non-favorite recipes", %{conn: conn, recipe3: recipe3} do
      {:ok, _view, html} = live(conn, ~p"/voting")

      refute html =~ recipe3.name
    end

    test "shows Start Voting button when no active session", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/voting")

      assert html =~ "Start Voting"
    end
  end

  describe "starting a vote" do
    test "creates a new voting session", %{conn: conn, account: account, user: user} do
      {:ok, view, _html} = live(conn, ~p"/voting")

      view
      |> element("button", "Start Voting")
      |> render_click()

      assert render(view) =~ "Voting session started"
      assert render(view) =~ "Time Remaining"

      session_id = account.id

      {:ok, session} =
        MealPlanVoteSession
        |> Ash.Query.filter(account_id == ^session_id and status == :open)
        |> Ash.read_one(tenant: account.id, actor: user)

      assert session != nil
      assert session.status == :open
    end

    test "prevents creating duplicate open sessions", %{
      conn: conn,
      account: account,
      user: user
    } do
      {:ok, _session} =
        MealPlanVoteSession
        |> Ash.Changeset.new()
        |> Ash.Changeset.set_argument(:account_id, account.id)
        |> Ash.Changeset.for_create(:start, %{})
        |> Ash.create(actor: user, tenant: account.id, authorize?: false)

      {:ok, view, _html} = live(conn, ~p"/voting")

      # When an open session exists, the UI should not show "Start Voting" button
      # It should show the voting interface instead
      refute render(view) =~ "Start Voting"
      assert render(view) =~ "Time Remaining"
    end
  end

  describe "casting votes" do
    setup %{conn: _conn, account: account, user: user} do
      {:ok, session} =
        MealPlanVoteSession
        |> Ash.Changeset.new()
        |> Ash.Changeset.set_argument(:account_id, account.id)
        |> Ash.Changeset.for_create(:start, %{})
        |> Ash.create(actor: user, tenant: account.id, authorize?: false)

      %{session: session}
    end

    test "allows voting on recipes", %{
      conn: conn,
      recipe1: recipe1,
      session: session,
      account: account,
      user: user
    } do
      {:ok, view, _html} = live(conn, ~p"/voting")

      view
      |> element("button[phx-value-id='#{recipe1.id}']")
      |> render_click()

      session_id = session.id
      recipe_id = recipe1.id
      user_id = user.id

      entries =
        MealPlanVoteEntry
        |> Ash.Query.filter(
          vote_session_id == ^session_id and recipe_id == ^recipe_id and user_id == ^user_id
        )
        |> Ash.read!(actor: user, tenant: account.id)

      assert length(entries) == 1
    end

    test "shows vote count on recipes", %{conn: conn, recipe1: recipe1} do
      {:ok, view, _html} = live(conn, ~p"/voting")

      view
      |> element("button[phx-value-id='#{recipe1.id}']")
      |> render_click()

      assert render(view) =~ "Votes:"
    end
  end

  describe "finalizing votes" do
    setup %{conn: _conn, account: account, user: user, recipe1: recipe1, recipe2: recipe2} do
      {:ok, session} =
        MealPlanVoteSession
        |> Ash.Changeset.new()
        |> Ash.Changeset.set_argument(:account_id, account.id)
        |> Ash.Changeset.for_create(:start, %{})
        |> Ash.create(actor: user, tenant: account.id, authorize?: false)

      # Create vote entries BEFORE updating ends_at
      {:ok, _entry1} =
        MealPlanVoteEntry
        |> Ash.Changeset.new()
        |> Ash.Changeset.set_argument(:account_id, account.id)
        |> Ash.Changeset.set_argument(:vote_session_id, session.id)
        |> Ash.Changeset.set_argument(:recipe_id, recipe1.id)
        |> Ash.Changeset.set_argument(:user_id, user.id)
        |> Ash.Changeset.for_create(:vote, %{})
        |> Ash.create(actor: user, tenant: account.id, authorize?: false)

      {:ok, _entry2} =
        MealPlanVoteEntry
        |> Ash.Changeset.new()
        |> Ash.Changeset.set_argument(:account_id, account.id)
        |> Ash.Changeset.set_argument(:vote_session_id, session.id)
        |> Ash.Changeset.set_argument(:recipe_id, recipe2.id)
        |> Ash.Changeset.set_argument(:user_id, user.id)
        |> Ash.Changeset.for_create(:vote, %{})
        |> Ash.create(actor: user, tenant: account.id, authorize?: false)

      # NOW update ends_at to the past so finalization is allowed
      session =
        session
        |> Ash.Changeset.for_update(:update, %{
          ends_at: DateTime.add(DateTime.utc_now(), -1, :second)
        })
        |> Ash.update!(actor: user, tenant: account.id)

      %{session: session}
    end

    test "creates meal plans from winning recipes", %{
      conn: conn,
      account: account,
      user: user
    } do
      {:ok, view, _html} = live(conn, ~p"/voting")

      view
      |> element("button", "Finalize")
      |> render_click()

      assert render(view) =~ "Voting finalized"

      account_id = account.id

      meal_plans =
        GroceryPlanner.MealPlanning.MealPlan
        |> Ash.Query.filter(account_id == ^account_id)
        |> Ash.read!(actor: user, tenant: account.id)

      assert length(meal_plans) > 0
    end

    # test "cannot finalize if session is still active", %{conn: conn, session: session, user: user, account: account} do
    #   # Update session to end in the future
    #   _session =
    #     session
    #     |> Ash.Changeset.for_update(:update, %{ends_at: DateTime.add(DateTime.utc_now(), 3600, :second)})
    #     |> Ash.update!(actor: user, tenant: account.id)

    #   {:ok, view, _html} = live(conn, ~p"/voting")

    #   view
    #   |> element("button", "Finalize")
    #   |> render_click()

    #   assert render(view) =~ "Voting still in progress"
    # end
  end

  describe "tick" do
    test "updates time remaining", %{conn: conn, account: account, user: user} do
      # Create active session
      {:ok, _session} =
        MealPlanVoteSession
        |> Ash.Changeset.new()
        |> Ash.Changeset.set_argument(:account_id, account.id)
        |> Ash.Changeset.for_create(:start, %{})
        |> Ash.create(actor: user, tenant: account.id, authorize?: false)

      {:ok, view, _html} = live(conn, ~p"/voting")

      # Send tick message
      send(view.pid, :tick)

      # Just verify it doesn't crash and re-renders
      assert render(view) =~ "Time Remaining"
    end
  end
end
