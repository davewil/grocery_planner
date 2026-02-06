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
    file_path = resolve_file_path(receipt.file_path)

    case File.read(file_path) do
      {:ok, file_data} ->
        image_base64 = Base.encode64(file_data)

        context = %{
          tenant_id: receipt.account_id,
          user_id: nil
        }

        AiClient.extract_receipt(image_base64, context)

      {:error, reason} ->
        Logger.error("Failed to read receipt file #{file_path}: #{inspect(reason)}")
        {:error, :file_read_failed}
    end
  end

  defp resolve_file_path(path) when is_binary(path) do
    if File.exists?(path) do
      path
    else
      # Try resolving web URL path to filesystem path
      resolved =
        Path.join([:code.priv_dir(:grocery_planner), "static", String.trim_leading(path, "/")])

      if File.exists?(resolved), do: resolved, else: path
    end
  end
end
