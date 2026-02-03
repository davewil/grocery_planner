defmodule GroceryPlannerWeb.InventoryLiveCategorizationTest do
  use GroceryPlannerWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import GroceryPlanner.InventoryTestHelpers

  setup do
    # Register a default stub so the global ai_client_opts plug doesn't crash
    # when categorization is disabled but the plug is still active.
    Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
      Req.Test.json(conn, %{
        "request_id" => "req_default",
        "status" => "success",
        "payload" => %{
          "category" => "Other",
          "confidence" => 0.5,
          "confidence_level" => "medium"
        }
      })
    end)

    account = create_account()
    user = create_user(account)

    conn =
      build_conn()
      |> init_test_session(%{
        user_id: user.id,
        account_id: account.id
      })

    %{conn: conn, account: account, user: user}
  end

  describe "suggest_category button" do
    test "does not crash when name is empty", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button", "New Item")
      |> render_click()

      # Initialize form with empty name first
      view
      |> form("#item-form", item: %{name: ""})
      |> render_change()

      # Try to suggest without a proper name - should not crash
      view
      |> element("button[phx-click='suggest_category']")
      |> render_click()

      # Form should still be visible (no crash)
      assert has_element?(view, "form#item-form")
    end

    test "does not trigger when categorization is disabled", %{
      conn: conn,
      account: account,
      user: user
    } do
      # Ensure categorization is disabled (it's disabled by default in test config)
      assert Application.get_env(:grocery_planner, :features)[:ai_categorization] == false

      _category = create_category(account, user, %{name: "Dairy"})

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button", "New Item")
      |> render_click()

      # Enter a name
      view
      |> form("#item-form", item: %{name: "Milk"})
      |> render_change()

      # Try to suggest - should not crash but also not show suggestion
      view
      |> element("button[phx-click='suggest_category']")
      |> render_click()

      # Wait a bit
      Process.sleep(100)

      html = render(view)
      refute html =~ "Suggested:"
    end

    test "makes API call and sets category when categorization is enabled", %{
      conn: conn,
      account: account,
      user: user
    } do
      # Enable AI categorization for this test
      Application.put_env(:grocery_planner, :features, ai_categorization: true)

      on_exit(fn ->
        Application.put_env(:grocery_planner, :features, ai_categorization: false)
      end)

      _category = create_category(account, user, %{name: "Dairy"})

      # Stub the HTTP request - response format must match AiClient expectations
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        assert conn.request_path == "/api/v1/categorize"
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["payload"]["item_name"] == "Milk"
        assert params["payload"]["candidate_labels"] == ["Dairy"]
        assert params["feature"] == "categorization"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "payload" => %{
              "category" => "Dairy",
              "confidence" => 0.95
            }
          })
        )
      end)

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button", "New Item")
      |> render_click()

      # Enter a name
      view
      |> form("#item-form", item: %{name: "Milk"})
      |> render_change()

      # Click suggest button
      view
      |> element("button[phx-click='suggest_category']")
      |> render_click()

      # Wait for async result
      assert_eventually(fn ->
        html = render(view)
        assert html =~ "Suggested:"
        assert html =~ "Dairy"
        assert html =~ "95%"
      end)
    end
  end

  describe "accept_suggestion event" do
    test "populates category_id in form from suggestion", %{
      conn: conn,
      account: account,
      user: user
    } do
      # Enable AI categorization for this test
      Application.put_env(:grocery_planner, :features, ai_categorization: true)

      on_exit(fn ->
        Application.put_env(:grocery_planner, :features, ai_categorization: false)
      end)

      _category = create_category(account, user, %{name: "Produce"})

      # Stub the HTTP request
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "payload" => %{
              "category" => "Produce",
              "confidence" => 0.88
            }
          })
        )
      end)

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button", "New Item")
      |> render_click()

      # Enter a name and trigger suggestion
      view
      |> form("#item-form", item: %{name: "Apple"})
      |> render_change()

      view
      |> element("button[phx-click='suggest_category']")
      |> render_click()

      # Wait for suggestion to appear
      assert_eventually(fn ->
        render(view) =~ "Suggested:"
      end)

      # Click accept suggestion
      view
      |> element("button[phx-click='accept_suggestion']")
      |> render_click()

      # Submit the form and verify category was set
      view
      |> form("#item-form")
      |> render_submit()

      # Verify the item was created with the correct category
      {:ok, items} =
        GroceryPlanner.Inventory.list_grocery_items(
          authorize?: false,
          tenant: account.id,
          load: [:category]
        )

      apple_item = Enum.find(items, fn item -> item.name == "Apple" end)
      assert apple_item != nil
      assert apple_item.category.name == "Produce"
    end
  end

  describe "auto-categorization on validate_item" do
    test "triggers when name >= 3 chars and categorization enabled", %{
      conn: conn,
      account: account,
      user: user
    } do
      # Enable AI categorization for this test
      Application.put_env(:grocery_planner, :features, ai_categorization: true)

      on_exit(fn ->
        Application.put_env(:grocery_planner, :features, ai_categorization: false)
      end)

      _category = create_category(account, user, %{name: "Bakery"})

      # Stub the HTTP request
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "payload" => %{
              "category" => "Bakery",
              "confidence" => 0.92
            }
          })
        )
      end)

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button", "New Item")
      |> render_click()

      # Type a name with >= 3 characters (triggers debounced validation)
      view
      |> form("#item-form", item: %{name: "Bread"})
      |> render_change()

      # Wait for auto-categorization to complete
      assert_eventually(fn ->
        html = render(view)
        assert html =~ "Suggested:"
        assert html =~ "Bakery"
        assert html =~ "92%"
      end)
    end

    test "does not trigger when name < 3 chars", %{conn: conn, account: account, user: user} do
      # Enable AI categorization for this test
      Application.put_env(:grocery_planner, :features, ai_categorization: true)

      on_exit(fn ->
        Application.put_env(:grocery_planner, :features, ai_categorization: false)
      end)

      _category = create_category(account, user, %{name: "Dairy"})

      # Stub should NOT be called
      Req.Test.stub(GroceryPlanner.AiClient, fn _conn ->
        flunk("Should not make API call for short names")
      end)

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button", "New Item")
      |> render_click()

      # Type a short name (< 3 chars)
      view
      |> form("#item-form", item: %{name: "AB"})
      |> render_change()

      # Wait a bit to ensure no suggestion appears
      Process.sleep(100)

      html = render(view)
      refute html =~ "Suggested:"
    end

    test "does not trigger when no categories exist", %{conn: conn} do
      # Enable AI categorization for this test
      Application.put_env(:grocery_planner, :features, ai_categorization: true)

      on_exit(fn ->
        Application.put_env(:grocery_planner, :features, ai_categorization: false)
      end)

      # No categories created

      # Stub should NOT be called
      Req.Test.stub(GroceryPlanner.AiClient, fn _conn ->
        flunk("Should not make API call when no categories exist")
      end)

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button", "New Item")
      |> render_click()

      # Type a name >= 3 chars
      view
      |> form("#item-form", item: %{name: "Milk"})
      |> render_change()

      # Wait a bit to ensure no suggestion appears
      Process.sleep(100)

      html = render(view)
      refute html =~ "Suggested:"
    end
  end

  describe "category suggestion display" do
    test "successfully processes categorization request", %{
      conn: conn,
      account: account,
      user: user
    } do
      # Enable AI categorization for this test
      Application.put_env(:grocery_planner, :features, ai_categorization: true)

      on_exit(fn ->
        Application.put_env(:grocery_planner, :features, ai_categorization: false)
      end)

      _category = create_category(account, user, %{name: "Dairy"})

      # Stub the request
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "payload" => %{
              "category" => "Dairy",
              "confidence" => 0.95
            }
          })
        )
      end)

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button", "New Item")
      |> render_click()

      view
      |> form("#item-form", item: %{name: "Milk"})
      |> render_change()

      view
      |> element("button[phx-click='suggest_category']")
      |> render_click()

      # Wait for suggestion to appear
      assert_eventually(fn ->
        html = render(view)
        assert html =~ "Suggested:"
        assert html =~ "Dairy"
      end)
    end

    test "displays confidence badge with correct styling", %{
      conn: conn,
      account: account,
      user: user
    } do
      # Enable AI categorization for this test
      Application.put_env(:grocery_planner, :features, ai_categorization: true)

      on_exit(fn ->
        Application.put_env(:grocery_planner, :features, ai_categorization: false)
      end)

      _category = create_category(account, user, %{name: "Snacks"})

      # Test with medium confidence
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "payload" => %{
              "category" => "Snacks",
              "confidence" => 0.65
            }
          })
        )
      end)

      {:ok, view, _html} = live(conn, "/inventory")

      view
      |> element("button", "New Item")
      |> render_click()

      view
      |> form("#item-form", item: %{name: "Chips"})
      |> render_change()

      view
      |> element("button[phx-click='suggest_category']")
      |> render_click()

      # Wait for suggestion
      assert_eventually(fn ->
        html = render(view)
        assert html =~ "65%"
        assert html =~ "badge-warning"
      end)
    end
  end

  # Helper function to poll until condition is met
  defp assert_eventually(assertion_fn, timeout \\ 2000, interval \\ 50) do
    start_time = System.monotonic_time(:millisecond)

    do_assert_eventually(assertion_fn, start_time, timeout, interval)
  end

  defp do_assert_eventually(assertion_fn, start_time, timeout, interval) do
    try do
      assertion_fn.()
    rescue
      error in [ExUnit.AssertionError] ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        if elapsed < timeout do
          Process.sleep(interval)
          do_assert_eventually(assertion_fn, start_time, timeout, interval)
        else
          reraise error, __STACKTRACE__
        end
    end
  end
end
