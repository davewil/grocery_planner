defmodule GroceryPlannerWeb.ReceiptLiveTest do
  use GroceryPlannerWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import GroceryPlanner.InventoryTestHelpers

  alias GroceryPlanner.Inventory
  alias GroceryPlanner.Inventory.ReceiptProcessor

  @receipt_fixture "test/fixtures/sample_receipt.png"

  setup do
    # Default AI stub so the global ai_client_opts plug doesn't crash
    Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
      Req.Test.json(conn, %{
        "request_id" => "req_default",
        "status" => "success",
        "payload" => %{}
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

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Creates a receipt directly via domain functions, bypassing file upload.
  defp create_test_receipt(account) do
    Inventory.create_receipt!(
      account.id,
      %{
        file_path: "/tmp/test_receipt_#{System.unique_integer([:positive])}.png",
        file_hash: "test_hash_#{System.unique_integer([:positive])}",
        file_size: 12345,
        mime_type: "image/png"
      },
      authorize?: false,
      tenant: account.id
    )
  end

  # Navigates a LiveView to the review step by creating a receipt with
  # extraction results and sending the :receipt_processed message.
  defp navigate_to_review(view, account, opts \\ []) do
    merchant = opts[:merchant] || "Test Grocery"
    date = opts[:date] || "2026-01-15"
    items = opts[:items] || default_items()

    receipt = create_test_receipt(account)

    extraction = %{
      "payload" => %{
        "items" => items,
        "merchant" => merchant,
        "date" => date
      }
    }

    {:ok, updated_receipt} = ReceiptProcessor.save_extraction_results(receipt, extraction)

    # Send the receipt_processed message directly to the LiveView process.
    # The handle_info handler will query receipt items from the DB.
    send(view.pid, {:receipt_processed, updated_receipt})

    # Wait for the view to process the message and transition to review step
    assert_eventually(fn ->
      html = render(view)
      assert html =~ "items extracted"
    end)

    updated_receipt
  end

  defp default_items do
    [
      %{"name" => "Whole Milk", "quantity" => 1, "unit" => "gallon", "confidence" => 0.95},
      %{"name" => "Bananas", "quantity" => 6, "unit" => "each", "confidence" => 0.92},
      %{"name" => "Bread", "quantity" => 1, "unit" => "loaf", "confidence" => 0.88}
    ]
  end

  defp assert_eventually(assertion_fn, timeout \\ 3000, interval \\ 50) do
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

  # ---------------------------------------------------------------------------
  # Step 1: Mount and upload step
  # ---------------------------------------------------------------------------

  describe "mount and upload step" do
    test "renders upload form on mount", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/receipts/scan")

      assert html =~ "Scan Receipt"
      assert html =~ "Upload Receipt"
      assert html =~ "upload-form"
    end

    test "shows file input and upload button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/receipts/scan")

      assert has_element?(view, "form#upload-form")
      assert has_element?(view, "button[type='submit']")
    end

    test "upload button is disabled without file", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/receipts/scan")

      assert html =~ "disabled"
      assert html =~ "Upload &amp; Process"
    end

    test "shows supported file types info", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/receipts/scan")

      assert html =~ "Supports JPEG, PNG, HEIC, PDF up to 10MB"
    end

    test "shows drag and drop area", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/receipts/scan")

      assert html =~ "Drag &amp; drop or click to select"
    end
  end

  # ---------------------------------------------------------------------------
  # Step 2: File upload flow
  # ---------------------------------------------------------------------------

  describe "file upload flow" do
    test "shows selected file name after choosing a file", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/receipts/scan")

      receipt_content = File.read!(@receipt_fixture)

      upload =
        file_input(view, "#upload-form", :receipt, [
          %{
            name: "my_grocery_receipt.png",
            content: receipt_content,
            type: "image/png"
          }
        ])

      # Preflight registers the entries with the LiveView, making them visible
      assert {:ok, _} = preflight_upload(upload)

      html = render(view)
      assert html =~ "my_grocery_receipt.png"
    end

    test "shows upload progress indicator for selected file", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/receipts/scan")

      receipt_content = File.read!(@receipt_fixture)

      upload =
        file_input(view, "#upload-form", :receipt, [
          %{
            name: "receipt.png",
            content: receipt_content,
            type: "image/png"
          }
        ])

      assert {:ok, _} = preflight_upload(upload)

      html = render(view)
      assert html =~ "progress"
    end

    test "cancel_upload button appears for selected file", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/receipts/scan")

      receipt_content = File.read!(@receipt_fixture)

      upload =
        file_input(view, "#upload-form", :receipt, [
          %{
            name: "receipt.png",
            content: receipt_content,
            type: "image/png"
          }
        ])

      assert {:ok, _} = preflight_upload(upload)

      assert has_element?(view, "button[phx-click='cancel_upload']")
    end
  end

  # ---------------------------------------------------------------------------
  # Step 3: Processing to review transition
  # ---------------------------------------------------------------------------

  describe "processing to review transition" do
    test "transitions to review step with items displayed", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, "/receipts/scan")

      navigate_to_review(view, account)

      html = render(view)
      assert html =~ "Whole Milk"
      assert html =~ "Bananas"
      assert html =~ "Bread"
      assert html =~ "Test Grocery"
    end

    test "displays merchant name and date in review summary", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, "/receipts/scan")

      navigate_to_review(view, account,
        merchant: "Corner Market",
        date: "2026-02-01",
        items: [%{"name" => "Eggs", "quantity" => 1, "unit" => "dozen", "confidence" => 0.90}]
      )

      html = render(view)
      assert html =~ "Corner Market"
      assert html =~ "February 01, 2026"
    end

    test "handles processing status updates without crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/receipts/scan")

      # The processing status message is accepted at any step without crashing.
      # The status text only renders on the :processing step, but the assign is
      # stored regardless of current step.
      send(view.pid, {:receipt_processing_status, "Extracting text..."})

      # Verify the view is still alive and rendering the upload step correctly
      assert_eventually(fn ->
        html = render(view)
        assert html =~ "Upload Receipt"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Step 4: Review step editing
  # ---------------------------------------------------------------------------

  describe "review step editing" do
    setup %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, "/receipts/scan")

      receipt = navigate_to_review(view, account)

      %{view: view, receipt: receipt}
    end

    test "displays extracted items with names and quantities", %{view: view} do
      html = render(view)

      assert html =~ "Whole Milk"
      assert html =~ "Bananas"
      assert html =~ "Bread"
    end

    test "displays item match status badges", %{view: view} do
      html = render(view)

      # Items without grocery_item_id should show "No match" badge
      assert html =~ "No match"
      assert html =~ "Will create new item"
    end

    test "allows editing item name", %{view: view} do
      view
      |> element("input[phx-blur='update_item_name'][phx-value-idx='0']")
      |> render_blur(%{"value" => "Organic Whole Milk"})

      html = render(view)
      assert html =~ "Organic Whole Milk"
    end

    test "allows editing item quantity", %{view: view} do
      view
      |> element("input[phx-blur='update_item_quantity'][phx-value-idx='1']")
      |> render_blur(%{"value" => "12"})

      html = render(view)
      assert html =~ "12"
    end

    test "allows editing item unit", %{view: view} do
      view
      |> element("input[phx-blur='update_item_unit'][phx-value-idx='0']")
      |> render_blur(%{"value" => "liter"})

      html = render(view)
      assert html =~ "liter"
    end

    test "allows removing an item", %{view: view} do
      html = render(view)
      assert html =~ "Bread"

      view
      |> element("button[phx-click='remove_item'][phx-value-idx='2']")
      |> render_click()

      html = render(view)
      refute html =~ "Bread"
    end

    test "allows adding a manual item", %{view: view} do
      view
      |> element("button[phx-click='add_manual_item']")
      |> render_click()

      html = render(view)
      assert html =~ "4 items"
    end

    test "shows Start Over and Add Item buttons", %{view: view} do
      assert has_element?(view, "button[phx-click='back_to_upload']")
      assert has_element?(view, "button[phx-click='add_manual_item']")
      assert has_element?(view, "button[phx-click='confirm_import']")
    end
  end

  # ---------------------------------------------------------------------------
  # Step 5: Confirm import
  # ---------------------------------------------------------------------------

  describe "confirm import" do
    setup %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, "/receipts/scan")

      receipt =
        navigate_to_review(view, account,
          items: [
            %{"name" => "Whole Milk", "quantity" => 1, "unit" => "gallon", "confidence" => 0.95},
            %{"name" => "Bananas", "quantity" => 6, "unit" => "each", "confidence" => 0.92}
          ]
        )

      %{view: view, receipt: receipt}
    end

    test "transitions to complete step on confirm", %{view: view} do
      view
      |> element("button[phx-click='confirm_import']")
      |> render_click()

      html = render(view)

      assert html =~ "Receipt Imported"
      assert html =~ "items added to your inventory"
    end

    test "complete step shows success message and navigation links", %{view: view} do
      view
      |> element("button[phx-click='confirm_import']")
      |> render_click()

      html = render(view)

      assert html =~ "Receipt Imported"
      assert html =~ "Scan Another Receipt"
      assert html =~ "View Inventory"
      assert html =~ ~r/href="\/inventory"/
    end
  end

  # ---------------------------------------------------------------------------
  # Step 6: Error handling
  # ---------------------------------------------------------------------------

  describe "error handling" do
    test "shows error when receipt processing fails via PubSub", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/receipts/scan")

      fake_receipt = %{id: Ecto.UUID.generate(), account_id: Ecto.UUID.generate()}
      send(view.pid, {:receipt_failed, fake_receipt, :ocr_service_unavailable})

      assert_eventually(fn ->
        html = render(view)
        assert html =~ "Processing failed"
        assert html =~ "ocr_service_unavailable"
      end)
    end

    test "receipt_failed returns to upload step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/receipts/scan")

      fake_receipt = %{id: Ecto.UUID.generate(), account_id: Ecto.UUID.generate()}
      send(view.pid, {:receipt_failed, fake_receipt, :timeout})

      assert_eventually(fn ->
        html = render(view)
        assert html =~ "Upload Receipt"
        assert html =~ "Processing failed"
      end)
    end

    test "back_to_upload returns to upload step from review", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, "/receipts/scan")

      navigate_to_review(view, account,
        items: [%{"name" => "Apple", "quantity" => 3, "unit" => "each", "confidence" => 0.90}]
      )

      assert render(view) =~ "Apple"

      view
      |> element("button[phx-click='back_to_upload']")
      |> render_click()

      html = render(view)
      assert html =~ "Upload Receipt"
      assert html =~ "upload-form"
      refute html =~ "Apple"
    end

    test "scan_another resets wizard from complete step", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, "/receipts/scan")

      navigate_to_review(view, account,
        items: [%{"name" => "Orange", "quantity" => 4, "unit" => "each", "confidence" => 0.85}]
      )

      view
      |> element("button[phx-click='confirm_import']")
      |> render_click()

      assert render(view) =~ "Receipt Imported"

      view
      |> element("button[phx-click='scan_another']")
      |> render_click()

      html = render(view)
      assert html =~ "Upload Receipt"
      assert html =~ "upload-form"
      refute html =~ "Receipt Imported"
    end

    test "clear_error dismisses error message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/receipts/scan")

      fake_receipt = %{id: Ecto.UUID.generate(), account_id: Ecto.UUID.generate()}
      send(view.pid, {:receipt_failed, fake_receipt, :timeout})

      assert_eventually(fn ->
        assert render(view) =~ "Processing failed"
      end)

      view
      |> element("button[phx-click='clear_error']")
      |> render_click()

      html = render(view)
      refute html =~ "Processing failed"
    end
  end

  # ---------------------------------------------------------------------------
  # Step indicator tests
  # ---------------------------------------------------------------------------

  describe "step indicator" do
    test "upload step is highlighted on mount", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/receipts/scan")

      assert html =~ "step step-primary"
      assert html =~ "Upload"
      assert html =~ "Processing"
      assert html =~ "Review"
      assert html =~ "Done"
    end

    test "review step shows correct step progression", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, "/receipts/scan")

      navigate_to_review(view, account)

      html = render(view)
      # Upload, Processing, and Review should all be step-primary
      matches = Regex.scan(~r/step step-primary/, html)
      assert length(matches) >= 3
    end

    test "complete step shows all steps as primary", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, "/receipts/scan")

      navigate_to_review(view, account)

      view
      |> element("button[phx-click='confirm_import']")
      |> render_click()

      html = render(view)
      matches = Regex.scan(~r/step step-primary/, html)
      assert length(matches) >= 4
    end
  end
end
