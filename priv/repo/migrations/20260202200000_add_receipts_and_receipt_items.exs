defmodule GroceryPlanner.Repo.Migrations.AddReceiptsAndReceiptItems do
  use Ecto.Migration

  def up do
    # Alter existing receipts table - rename columns
    rename table(:receipts), :image_path, to: :file_path
    rename table(:receipts), :merchant, to: :merchant_name
    rename table(:receipts), :scanned_date, to: :purchase_date

    alter table(:receipts) do
      # Remove columns that are no longer needed
      remove :items
      remove :job_id

      # Replace total_amount (was :decimal, now :money_with_currency)
      remove :total_amount
      add :total_amount, :money_with_currency

      # Change column types: file_path from :text to :string (varchar)
      modify :file_path, :string, null: false
      # Change merchant_name from :text to :string (varchar)
      modify :merchant_name, :string
      # Change status from :text to :string (varchar)
      modify :status, :string, default: "pending", null: false

      # Add new columns
      add :user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :file_hash, :string
      add :file_size, :integer
      add :mime_type, :string
      add :raw_ocr_text, :text
      add :extraction_confidence, :float
      add :model_version, :string
      add :processed_at, :utc_datetime_usec
      add :error_message, :text
      add :processing_time_ms, :integer
    end

    create index(:receipts, [:file_hash])
    create index(:receipts, [:status])

    # Create receipt_items table
    create table(:receipt_items, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :receipt_id, references(:receipts, type: :uuid, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, type: :uuid, on_delete: :delete_all), null: false

      # Raw extracted data
      add :raw_name, :string, null: false
      add :quantity, :decimal
      add :unit, :string
      add :unit_price, :money_with_currency
      add :total_price, :money_with_currency
      add :confidence, :float

      # Matching/correction
      add :grocery_item_id, references(:grocery_items, type: :uuid, on_delete: :nilify_all)
      add :match_confidence, :float
      add :user_corrected, :boolean, default: false, null: false
      add :final_name, :string
      add :final_quantity, :decimal
      add :final_unit, :string
      add :status, :string, default: "pending", null: false

      # Inventory integration
      add :inventory_entry_id, references(:inventory_entries, type: :uuid, on_delete: :nilify_all)

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:receipt_items, [:receipt_id])
    create index(:receipt_items, [:grocery_item_id])
  end

  def down do
    # Drop receipt_items table
    drop index(:receipt_items, [:grocery_item_id])
    drop index(:receipt_items, [:receipt_id])
    drop table(:receipt_items)

    # Reverse receipts alterations
    drop index(:receipts, [:status])
    drop index(:receipts, [:file_hash])

    alter table(:receipts) do
      # Remove new columns
      remove :processing_time_ms
      remove :error_message
      remove :processed_at
      remove :model_version
      remove :extraction_confidence
      remove :raw_ocr_text
      remove :mime_type
      remove :file_size
      remove :file_hash
      remove :user_id

      # Restore total_amount as :decimal
      remove :total_amount
      add :total_amount, :decimal

      # Restore removed columns
      add :job_id, :text
      add :items, {:array, :map}, default: []

      # Revert column types back to :text
      modify :status, :text, default: "pending", null: false
      modify :merchant_name, :text
      modify :file_path, :text, null: false
    end

    # Reverse renames
    rename table(:receipts), :purchase_date, to: :scanned_date
    rename table(:receipts), :merchant_name, to: :merchant
    rename table(:receipts), :file_path, to: :image_path
  end
end
