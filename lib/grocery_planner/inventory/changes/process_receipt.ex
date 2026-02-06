defmodule GroceryPlanner.Inventory.Changes.ProcessReceipt do
  @moduledoc """
  Ash change that processes a receipt through the OCR pipeline.
  Called by AshOban trigger when receipt status is :pending.
  """
  use Ash.Resource.Change

  require Logger

  alias GroceryPlanner.AiClient
  alias GroceryPlanner.Inventory.ReceiptProcessor

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, receipt ->
      Logger.info("Processing receipt #{receipt.id}")

      case process_receipt(receipt) do
        {:ok, updated_receipt} ->
          Logger.info("Receipt #{receipt.id} processed successfully")

          Phoenix.PubSub.broadcast(
            GroceryPlanner.PubSub,
            "receipt:#{receipt.id}",
            {:receipt_processed, updated_receipt}
          )

          {:ok, updated_receipt}

        {:error, reason} ->
          Logger.error("Receipt processing failed for #{receipt.id}: #{inspect(reason)}")
          broadcast_failure(receipt, reason)
          {:error, format_error(reason)}
      end
    end)
  end

  defp process_receipt(receipt) do
    with {:ok, extraction} <- call_extraction_service(receipt),
         {:ok, updated_receipt} <- ReceiptProcessor.save_extraction_results(receipt, extraction) do
      {:ok, updated_receipt}
    end
  rescue
    e ->
      Logger.error("Unexpected error processing receipt #{receipt.id}: #{Exception.message(e)}")
      {:error, Exception.message(e)}
  end

  defp broadcast_failure(receipt, reason) do
    Phoenix.PubSub.broadcast(
      GroceryPlanner.PubSub,
      "receipt:#{receipt.id}",
      {:receipt_failed, receipt, reason}
    )
  end

  defp format_error(reason) when is_binary(reason) do
    Ash.Error.Changes.InvalidChanges.exception(
      fields: [:status],
      message: reason
    )
  end

  defp format_error(reason) do
    Ash.Error.Changes.InvalidChanges.exception(
      fields: [:status],
      message: "Processing failed: #{inspect(reason)}"
    )
  end

  defp call_extraction_service(receipt) do
    file_path = resolve_file_path(receipt.file_path)

    case File.read(file_path) do
      {:ok, file_data} ->
        image_base64 = Base.encode64(file_data)

        context = %{
          tenant_id: receipt.account_id,
          user_id: "system"
        }

        AiClient.extract_receipt(image_base64, context)

      {:error, reason} ->
        Logger.error("Failed to read receipt file #{file_path}: #{inspect(reason)}")
        {:error, :file_read_failed}
    end
  end

  defp resolve_file_path(path) when is_binary(path) do
    cond do
      File.exists?(path) ->
        path

      true ->
        # Try multiple resolution strategies
        priv_dir = :code.priv_dir(:grocery_planner) |> to_string()

        candidates = [
          # Web URL path -> priv/static path
          Path.join([priv_dir, "static", String.trim_leading(path, "/")]),
          # Basename in receipts upload dir
          Path.join([priv_dir, "uploads", "receipts", Path.basename(path)]),
          # Basename in static uploads
          Path.join([priv_dir, "static", "uploads", Path.basename(path)])
        ]

        Enum.find(candidates, path, &File.exists?/1)
    end
  end
end
