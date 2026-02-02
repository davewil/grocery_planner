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

      with {:ok, extraction} <- call_extraction_service(receipt),
           {:ok, updated_receipt} <- ReceiptProcessor.save_extraction_results(receipt, extraction) do
        Logger.info("Receipt #{receipt.id} processed successfully")

        Phoenix.PubSub.broadcast(
          GroceryPlanner.PubSub,
          "receipt:#{receipt.id}",
          {:receipt_processed, updated_receipt}
        )

        {:ok, updated_receipt}
      else
        {:error, reason} ->
          Logger.error("Receipt processing failed for #{receipt.id}: #{inspect(reason)}")
          {:error, reason}
      end
    end)
  end

  defp call_extraction_service(receipt) do
    case File.read(receipt.file_path) do
      {:ok, file_data} ->
        image_base64 = Base.encode64(file_data)

        context = %{
          tenant_id: receipt.account_id,
          user_id: nil
        }

        AiClient.extract_receipt(image_base64, context)

      {:error, reason} ->
        Logger.error("Failed to read receipt file #{receipt.file_path}: #{inspect(reason)}")
        {:error, :file_read_failed}
    end
  end
end
