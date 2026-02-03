defmodule GroceryPlanner.Inventory.ReceiptProcessor do
  @moduledoc """
  Handles receipt upload, processing, and item extraction.
  Coordinates file storage, OCR service calls, and result persistence.
  """

  require Logger

  alias GroceryPlanner.Inventory

  @upload_dir Application.compile_env(
                :grocery_planner,
                :receipt_upload_dir,
                "priv/uploads/receipts"
              )

  @doc """
  Uploads a receipt file, stores it locally, and queues background processing.
  Returns {:ok, receipt} or {:error, reason}.
  """
  def upload(file_params, _user, account) do
    with {:ok, file_path, file_hash, file_size, mime_type} <- store_file(file_params),
         :ok <- check_duplicate(file_hash, account.id),
         {:ok, receipt} <- create_receipt(file_path, file_hash, file_size, mime_type, account) do
      # AshOban scheduler automatically picks up receipts with status: :pending
      {:ok, receipt}
    end
  end

  @doc """
  Stores an uploaded file to the local filesystem.
  file_params should have :path (temp path) and :client_name (original filename).
  Returns {:ok, dest_path, sha256_hash, file_size, mime_type}.
  """
  def store_file(%{path: temp_path, client_name: filename}) do
    # Ensure upload directory exists
    File.mkdir_p!(@upload_dir)

    # Generate unique filename
    ext = Path.extname(filename)
    unique_name = "#{Ecto.UUID.generate()}#{ext}"
    dest_path = Path.join(@upload_dir, unique_name)

    # Compute hash before moving
    file_hash = compute_file_hash(temp_path)
    %{size: file_size} = File.stat!(temp_path)
    mime_type = detect_mime_type(filename)

    # Copy file to uploads directory
    File.cp!(temp_path, dest_path)

    {:ok, dest_path, file_hash, file_size, mime_type}
  rescue
    e ->
      Logger.error("Failed to store receipt file: #{inspect(e)}")
      {:error, :file_storage_failed}
  end

  @doc """
  Computes SHA256 hash of a file for duplicate detection.
  """
  def compute_file_hash(file_path) do
    File.stream!(file_path, 2048)
    |> Enum.reduce(:crypto.hash_init(:sha256), fn chunk, acc ->
      :crypto.hash_update(acc, chunk)
    end)
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end

  @doc """
  Checks if a receipt with the same hash already exists for this account.
  """
  def check_duplicate(file_hash, account_id) do
    case Inventory.find_receipt_by_hash(file_hash, authorize?: false, tenant: account_id) do
      {:ok, nil} -> :ok
      {:ok, _existing} -> {:error, :duplicate_receipt}
      # If query fails, allow upload
      {:error, _} -> :ok
    end
  end

  @doc """
  Processes extraction results from the OCR service and creates receipt items.
  Returns {:ok, updated_receipt}.
  """
  def save_extraction_results(receipt, extraction) do
    # Extract payload from the API response
    payload = extraction["payload"] || %{}

    # Parse flat response format from Python service
    merchant_name = payload["merchant"]
    total_amount = parse_flat_money(payload["total"])

    # Update receipt with extraction metadata
    {:ok, updated_receipt} =
      Inventory.update_receipt(
        receipt,
        %{
          status: :completed,
          merchant_name: merchant_name,
          # Not provided in current API response
          purchase_date: nil,
          total_amount: total_amount,
          # Not provided in current API response
          raw_ocr_text: nil,
          # Not provided in current API response
          extraction_confidence: nil,
          # Not provided in current API response
          model_version: nil,
          # Not provided in current API response
          processing_time_ms: nil,
          processed_at: DateTime.utc_now()
        },
        authorize?: false,
        tenant: receipt.account_id
      )

    # Create receipt items from flat items array
    items = payload["items"] || []

    Enum.each(items, fn item ->
      Inventory.create_receipt_item(
        updated_receipt.id,
        receipt.account_id,
        %{
          raw_name: item["name"] || "Unknown",
          quantity: parse_decimal(item["quantity"]),
          unit: item["unit"],
          unit_price: parse_flat_money(item["price"]),
          total_price: parse_flat_money(item["price"], item["quantity"]),
          # Not provided in current API response
          confidence: nil,
          final_name: item["name"]
        },
        authorize?: false,
        tenant: receipt.account_id
      )
    end)

    # Batch categorize extracted items (non-critical, async)
    if GroceryPlanner.AI.Categorizer.enabled?() do
      Task.start(fn ->
        categorize_extracted_items(updated_receipt, receipt.account_id)
      end)
    end

    {:ok, updated_receipt}
  end

  @doc """
  Creates inventory entries from confirmed receipt items.
  """
  def create_inventory_entries(receipt, opts \\ []) do
    storage_location_id = opts[:storage_location_id]

    case Inventory.list_receipt_items_for_receipt(receipt.id,
           authorize?: false,
           tenant: receipt.account_id
         ) do
      {:ok, receipt_items} ->
        results =
          receipt_items
          |> Enum.filter(fn item -> item.status == :confirmed end)
          |> Enum.map(fn item ->
            create_entry_from_item(item, storage_location_id, receipt)
          end)

        {:ok, results}

      error ->
        error
    end
  end

  @doc """
  Batch-categorizes extracted receipt items using AI.
  Returns {:ok, predictions} or {:error, reason}.
  Non-critical - failures are logged but don't affect receipt processing.
  """
  def categorize_extracted_items(receipt, account_id) do
    alias GroceryPlanner.AI.Categorizer

    with {:ok, items} <-
           Inventory.list_receipt_items_for_receipt(receipt.id,
             authorize?: false,
             tenant: account_id
           ) do
      item_names = Enum.map(items, & &1.raw_name)

      if item_names == [] do
        {:ok, []}
      else
        opts = [
          tenant_id: account_id,
          user_id: "system"
        ]

        case Categorizer.predict_batch(item_names, opts) do
          {:ok, predictions} ->
            Logger.info(
              "Batch categorized #{length(predictions)} receipt items for receipt #{receipt.id}"
            )

            {:ok, predictions}

          {:error, reason} ->
            Logger.warning(
              "Batch categorization failed for receipt #{receipt.id}: #{inspect(reason)}"
            )

            {:error, reason}
        end
      end
    end
  rescue
    e ->
      Logger.warning("Batch categorization error for receipt #{receipt.id}: #{inspect(e)}")
      {:error, :categorization_failed}
  end

  # --- Private Helpers ---

  defp create_receipt(file_path, file_hash, file_size, mime_type, account) do
    Inventory.create_receipt(
      account.id,
      %{
        file_path: file_path,
        file_hash: file_hash,
        file_size: file_size,
        mime_type: mime_type
      },
      actor: nil,
      tenant: account.id
    )
  end

  defp create_entry_from_item(item, storage_location_id, receipt) do
    attrs = %{
      quantity: item.final_quantity || item.quantity || Decimal.new(1),
      unit: item.final_unit || item.unit,
      purchase_date: receipt.purchase_date || Date.utc_today(),
      purchase_price: item.total_price
    }

    attrs =
      if storage_location_id,
        do: Map.put(attrs, :storage_location_id, storage_location_id),
        else: attrs

    Inventory.create_inventory_entry(
      receipt.account_id,
      item.grocery_item_id,
      attrs,
      authorize?: false,
      tenant: receipt.account_id
    )
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_money(nil), do: nil

  defp parse_money(%{"amount" => amount, "currency" => currency}) do
    Money.new(amount, currency)
  rescue
    _ -> nil
  end

  defp parse_money(_), do: nil

  defp parse_flat_money(nil), do: nil
  defp parse_flat_money(nil, _quantity), do: nil

  defp parse_flat_money(amount) when is_number(amount) do
    Money.new(amount, :USD)
  rescue
    _ -> nil
  end

  defp parse_flat_money(amount, quantity) when is_number(amount) and is_number(quantity) do
    Money.new(amount * quantity, :USD)
  rescue
    _ -> nil
  end

  defp parse_flat_money(amount, _quantity) when is_number(amount) do
    parse_flat_money(amount)
  end

  defp parse_flat_money(_), do: nil
  defp parse_flat_money(_, _), do: nil

  defp parse_decimal(nil), do: nil
  defp parse_decimal(val) when is_number(val), do: Decimal.new("#{val}")

  defp parse_decimal(val) when is_binary(val) do
    case Decimal.parse(val) do
      {decimal, _} -> decimal
      :error -> nil
    end
  end

  defp detect_mime_type(filename) do
    case filename |> Path.extname() |> String.downcase() do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".heic" -> "image/heic"
      ".pdf" -> "application/pdf"
      _ -> "application/octet-stream"
    end
  end
end
