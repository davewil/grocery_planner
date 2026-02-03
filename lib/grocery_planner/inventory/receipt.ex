defmodule GroceryPlanner.Inventory.Receipt do
  @moduledoc """
  Represents an uploaded receipt with OCR extraction results.
  """
  use Ash.Resource,
    domain: GroceryPlanner.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshOban]

  postgres do
    table "receipts"
    repo GroceryPlanner.Repo
  end

  oban do
    triggers do
      trigger :process do
        queue(:ai_jobs)
        action :process
        where expr(status == :pending)
        max_attempts(3)
        read_action :pending_for_scheduler
        worker_read_action(:read)
        on_error(:on_process_error)
        scheduler_cron("* * * * *")
        scheduler_module_name(GroceryPlanner.Workers.ReceiptProcessScheduler)
        worker_module_name(GroceryPlanner.Workers.ReceiptProcessWorker)
      end
    end
  end

  code_interface do
    define :create
    define :read
    define :list_all
    define :get_by_id, action: :read, get_by: [:id]
    define :update
    define :destroy
    define :find_by_hash, args: [:file_hash]
  end

  actions do
    defaults [:read, :destroy]

    read :list_all do
      prepare build(sort: [created_at: :desc])
    end

    read :pending_for_scheduler do
      multitenancy :allow_global
      filter expr(status == :pending)
      pagination keyset?: true
    end

    read :find_by_hash do
      argument :file_hash, :string, allow_nil?: false
      filter expr(file_hash == ^arg(:file_hash))
    end

    create :create do
      accept [:file_path, :file_hash, :file_size, :mime_type]
      argument :account_id, :uuid, allow_nil?: false
      change manage_relationship(:account_id, :account, type: :append)
    end

    update :update do
      accept [
        :status,
        :merchant_name,
        :purchase_date,
        :total_amount,
        :raw_ocr_text,
        :extraction_confidence,
        :model_version,
        :processed_at,
        :error_message,
        :processing_time_ms
      ]

      require_atomic? false
    end

    update :process do
      require_atomic? false
      change set_attribute(:status, :processing)
      change GroceryPlanner.Inventory.Changes.ProcessReceipt
    end

    update :on_process_error do
      accept []
      require_atomic? false
      change set_attribute(:status, :failed)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action(:process) do
      authorize_if always()
    end

    policy action(:on_process_error) do
      authorize_if always()
    end

    policy action_type([:update, :destroy]) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end
  end

  multitenancy do
    strategy :attribute
    attribute :account_id
  end

  attributes do
    uuid_primary_key :id

    attribute :file_path, :string do
      allow_nil? false
      public? true
    end

    attribute :file_hash, :string do
      public? true
    end

    attribute :file_size, :integer do
      public? true
    end

    attribute :mime_type, :string do
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:pending, :processing, :completed, :failed]
      default :pending
      allow_nil? false
      public? true
    end

    attribute :merchant_name, :string do
      public? true
    end

    attribute :purchase_date, :date do
      public? true
    end

    attribute :total_amount, AshMoney.Types.Money do
      public? true
    end

    attribute :raw_ocr_text, :string do
      public? true
    end

    attribute :extraction_confidence, :float do
      public? true
    end

    attribute :model_version, :string do
      public? true
    end

    attribute :processed_at, :utc_datetime do
      public? true
    end

    attribute :error_message, :string do
      public? true
    end

    attribute :processing_time_ms, :integer do
      public? true
    end

    attribute :account_id, :uuid do
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :account, GroceryPlanner.Accounts.Account do
      allow_nil? false
      attribute_writable? true
    end

    has_many :receipt_items, GroceryPlanner.Inventory.ReceiptItem
  end
end
