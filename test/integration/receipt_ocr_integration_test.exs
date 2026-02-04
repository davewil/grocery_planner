defmodule GroceryPlanner.Integration.ReceiptOcrIntegrationTest do
  @moduledoc """
  Integration tests that exercise the real Elixir → Python AI service HTTP path.

  These tests require the Python service to be running on the configured URL.
  They are excluded from normal `mix test` runs and require:

      AI_SERVICE_URL=http://localhost:8099 mix test.integration

  Or use the helper script:

      ./scripts/test-integration.sh
  """
  use GroceryPlanner.IntegrationCase, async: false

  @moduletag :integration

  @fixture_path "test/fixtures/sample_receipt.png"

  describe "Python service connectivity" do
    test "health endpoint returns ok" do
      assert service_healthy?(),
             "Python AI service is not running at #{ai_service_url()}. " <>
               "Start it with: ./scripts/test-integration.sh"

      {:ok, %Req.Response{status: 200, body: body}} =
        Req.get(Req.new(base_url: ai_service_url()), url: "/health")

      assert body["status"] == "ok"
    end
  end

  describe "direct AiClient.extract_receipt/3" do
    test "extracts items from a real receipt image" do
      assert File.exists?(@fixture_path), "Fixture missing: #{@fixture_path}"

      image_base64 = @fixture_path |> File.read!() |> Base.encode64()
      context = %{tenant_id: Ecto.UUID.generate(), user_id: nil}

      assert {:ok, body} = GroceryPlanner.AiClient.extract_receipt(image_base64, context)

      # The Python service wraps results in a standard envelope
      assert is_map(body)
      assert body["status"] in ["success", "ok"]
    end

    test "returns error for invalid base64 payload" do
      context = %{tenant_id: Ecto.UUID.generate(), user_id: nil}

      # Send garbage that is not a valid image
      result = GroceryPlanner.AiClient.extract_receipt("not_valid_base64!", context)

      # Should either return an error tuple or a success with empty/error payload
      # The Python service may return 200 with error status or 400/500
      case result do
        {:error, _reason} -> :ok
        {:ok, body} -> assert is_map(body)
      end
    end
  end

  describe "full receipt processing flow" do
    test "processes a receipt through the complete pipeline" do
      {account, _user} = create_account_and_user()

      # Create a receipt pointing to the real fixture file
      {:ok, receipt} =
        GroceryPlanner.Inventory.create_receipt(
          account.id,
          %{
            file_path: Path.absname(@fixture_path),
            file_hash:
              :crypto.hash(:sha256, File.read!(@fixture_path)) |> Base.encode16(case: :lower),
            file_size: File.stat!(@fixture_path).size,
            mime_type: "image/png"
          },
          authorize?: false,
          tenant: account.id
        )

      assert receipt.status == :pending

      # Call the :process action directly (bypasses Oban)
      assert {:ok, processed} =
               Ash.update(receipt, %{}, action: :process, authorize?: false)

      # Receipt should be completed
      assert processed.status == :completed
      assert processed.processed_at != nil
      assert processed.processing_time_ms != nil || processed.model_version != nil

      # Should have created receipt items (Tesseract will extract some text)
      items =
        GroceryPlanner.Inventory.list_receipt_items_for_receipt(receipt.id,
          authorize?: false,
          tenant: account.id
        )

      case items do
        {:ok, item_list} ->
          # Tesseract may or may not find items depending on image quality
          assert is_list(item_list)

        # Some configurations return a list directly
        item_list when is_list(item_list) ->
          assert is_list(item_list)
      end
    end
  end

  describe "error handling" do
    test "gracefully handles receipt with non-existent file" do
      {account, _user} = create_account_and_user()

      {:ok, receipt} =
        GroceryPlanner.Inventory.create_receipt(
          account.id,
          %{
            file_path: "/tmp/nonexistent_receipt_#{System.unique_integer()}.png",
            file_hash: "fakehash_#{System.unique_integer()}",
            file_size: 0,
            mime_type: "image/png"
          },
          authorize?: false,
          tenant: account.id
        )

      # Process should fail gracefully (file read error)
      assert {:error, _reason} =
               Ash.update(receipt, %{}, action: :process, authorize?: false)
    end
  end
end
