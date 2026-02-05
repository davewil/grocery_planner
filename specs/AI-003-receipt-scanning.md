# AI-003: Receipt Scanning & Parsing

## Overview

**Feature:** Upload receipt images/PDFs and extract line items using OCR and structured extraction
**Priority:** High
**Epic:** RCP-01 (Receipt Ingestion)
**Estimated Effort:** 7-10 days

## Problem Statement

After a shopping trip, users must manually enter each purchased item into their inventory. This is time-consuming, error-prone, and leads to low adoption of inventory tracking.

**Current Pain Points:**
- Manual entry takes 5-10 minutes per shopping trip
- Users forget to log purchases
- Inconsistent data entry (quantities, units, prices)
- No connection between purchases and spending analytics

## User Stories

### US-001: Upload receipt image
**As a** user returning from shopping
**I want** to upload a photo of my receipt
**So that** the system can extract items automatically

**Acceptance Criteria:**
- [x] Support image upload (JPEG, PNG, HEIC)
- [x] Support PDF upload
- [ ] Camera capture on mobile devices
- [x] Show upload progress indicator
- [x] Handle images up to 10MB
- [x] Display processing status (uploading → processing → ready)

### US-002: Review and correct extracted items
**As a** user reviewing extracted data
**I want** to correct any OCR errors
**So that** my inventory stays accurate

**Acceptance Criteria:**
- [x] Display extracted items in editable list
- [x] Each item shows: name, quantity, unit, price
- [x] Items can be edited inline
- [x] Items can be deleted
- [x] Add missing items manually
- [x] Show confidence indicators for uncertain extractions
- [ ] "Looks wrong? Upload clearer image" option

### US-003: Match items to catalog
**As a** user confirming extracted items
**I want** items matched to my existing grocery catalog
**So that** inventory entries are consistent

**Acceptance Criteria:**
- [x] Auto-suggest matching GroceryItem from catalog
- [x] Show match confidence (high/medium/low)
- [x] Allow user to select different match
- [x] Create new GroceryItem if no match exists
- [x] Remember user corrections for future matching

### US-004: Add to inventory
**As a** user finalizing receipt import
**I want** confirmed items added to my inventory
**So that** my stock levels are updated

**Acceptance Criteria:**
- [x] Create InventoryEntry for each confirmed item
- [x] Set purchase date from receipt (or today)
- [x] Set purchase price from receipt
- [ ] Select default storage location
- [ ] Option to set expiration dates
- [x] Show success summary with count of items added

### US-005: Prevent duplicate imports
**As a** user
**I want** the system to detect duplicate receipts
**So that** I don't accidentally double-import items

**Acceptance Criteria:**
- [x] Compute hash of receipt image/content
- [x] Warn if same receipt uploaded before
- [ ] Option to proceed anyway or cancel
- [ ] Show link to previous import

## Technical Specification

### Architecture

```
┌─────────────────┐     1. Upload      ┌──────────────────┐
│  Elixir/Phoenix │ ──────────────────►│   File Storage   │
│   (LiveView)    │                    │   (Local/S3)     │
└────────┬────────┘                    └──────────────────┘
         │                                      │
         │  2. Process                          │
         ▼                                      │
┌─────────────────┐     3. Extract     ┌───────┴──────────┐
│   Oban Worker   │ ──────────────────►│  Python/FastAPI  │
│   (Background)  │                    │   (OCR Service)  │
└────────┬────────┘                    └──────────────────┘
         │                                      │
         │  4. Store Results                    │
         ▼                                      │
┌─────────────────┐                             │
│   PostgreSQL    │◄────────────────────────────┘
│   (Receipts)    │     5. Return JSON
└─────────────────┘
```

### Database Schema

**Tables:**

```elixir
defmodule GroceryPlanner.Repo.Migrations.AddReceipts do
  use Ecto.Migration

  def change do
    create table(:receipts, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :account_id, references(:accounts, type: :uuid, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :uuid, on_delete: :nilify_all)

      # File info
      add :file_path, :string, null: false
      add :file_hash, :string, null: false  # SHA256 for duplicate detection
      add :file_size, :integer
      add :mime_type, :string

      # Extraction metadata
      add :status, :string, default: "pending"  # pending, processing, completed, failed
      add :merchant_name, :string
      add :purchase_date, :date
      add :total_amount, :money_with_currency
      add :raw_ocr_text, :text
      add :extraction_confidence, :float
      add :model_version, :string

      # Processing info
      add :processed_at, :utc_datetime
      add :error_message, :text
      add :processing_time_ms, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:receipts, [:account_id])
    create index(:receipts, [:file_hash])
    create index(:receipts, [:status])

    create table(:receipt_items, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :receipt_id, references(:receipts, type: :uuid, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, type: :uuid, on_delete: :delete_all), null: false

      # Extracted data
      add :raw_name, :string, null: false  # Original OCR text
      add :quantity, :decimal
      add :unit, :string
      add :unit_price, :money_with_currency
      add :total_price, :money_with_currency
      add :confidence, :float

      # Matching
      add :grocery_item_id, references(:grocery_items, type: :uuid, on_delete: :nilify_all)
      add :match_confidence, :float
      add :user_corrected, :boolean, default: false

      # Final values (after user review)
      add :final_name, :string
      add :final_quantity, :decimal
      add :final_unit, :string

      # Status
      add :status, :string, default: "pending"  # pending, confirmed, skipped
      add :inventory_entry_id, references(:inventory_entries, type: :uuid, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:receipt_items, [:receipt_id])
    create index(:receipt_items, [:grocery_item_id])
  end
end
```

### Python Service Endpoints

#### Extract Receipt

**Endpoint:** `POST /api/v1/receipts/extract`

**Request:**
```json
{
  "version": "1.0",
  "request_id": "uuid",
  "account_id": "uuid",
  "image_url": "https://storage.example.com/receipts/abc123.jpg",
  "options": {
    "detect_merchant": true,
    "detect_date": true,
    "detect_total": true
  }
}
```

**Response:**
```json
{
  "version": "1.0",
  "request_id": "uuid",
  "status": "success",
  "processing_time_ms": 2340,
  "model_version": "tesseract-5.3.0+layoutlm-base",
  "extraction": {
    "merchant": {
      "name": "Whole Foods Market",
      "confidence": 0.92
    },
    "date": {
      "value": "2026-01-10",
      "confidence": 0.88
    },
    "total": {
      "amount": "87.43",
      "currency": "USD",
      "confidence": 0.95
    },
    "line_items": [
      {
        "raw_text": "ORG WHOLE MILK 1GL",
        "parsed_name": "Organic Whole Milk",
        "quantity": 1,
        "unit": "gallon",
        "unit_price": {"amount": "6.99", "currency": "USD"},
        "total_price": {"amount": "6.99", "currency": "USD"},
        "confidence": 0.89
      },
      {
        "raw_text": "BANANAS 2.3 LB",
        "parsed_name": "Bananas",
        "quantity": 2.3,
        "unit": "lb",
        "unit_price": {"amount": "0.79", "currency": "USD"},
        "total_price": {"amount": "1.82", "currency": "USD"},
        "confidence": 0.94
      }
    ],
    "raw_ocr_text": "WHOLE FOODS MARKET\n123 Main St...",
    "overall_confidence": 0.87
  }
}
```

### OCR Pipeline

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Image     │───►│  Pre-proc   │───►│    OCR      │───►│  Post-proc  │
│   Input     │    │  (Deskew,   │    │ (Tesseract/ │    │  (Parse,    │
│             │    │   Denoise)  │    │  EasyOCR)   │    │   Clean)    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                │
                                                                ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Output    │◄───│   Extract   │◄───│   NER /     │◄───│  Structure  │
│   JSON      │    │   Fields    │    │  LayoutLM   │    │  Detection  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

**Processing Steps:**

1. **Pre-processing**
   - Resize if too large (max 4000px)
   - Deskew (correct rotation)
   - Denoise (remove artifacts)
   - Enhance contrast

2. **OCR**
   - Primary: Tesseract 5.x with LSTM
   - Fallback: EasyOCR for difficult images
   - Output: Raw text + bounding boxes

3. **Structure Detection**
   - Identify receipt layout (header, items, footer)
   - Group text into logical lines
   - Detect table structure

4. **Named Entity Recognition**
   - LayoutLM for document understanding
   - Extract: merchant, date, items, prices
   - Handle various receipt formats

5. **Post-processing**
   - Clean item names (remove abbreviations)
   - Parse quantities and units
   - Validate prices (unit * qty = total)
   - Assign confidence scores

### Elixir Integration

**Module:** `GroceryPlanner.Inventory.ReceiptProcessor`

```elixir
defmodule GroceryPlanner.Inventory.ReceiptProcessor do
  @moduledoc """
  Handles receipt upload, processing, and item extraction.
  """

  alias GroceryPlanner.Inventory.{Receipt, ReceiptItem}
  alias GroceryPlanner.Workers.ReceiptProcessingWorker

  @doc """
  Uploads a receipt file and queues it for processing.
  """
  @spec upload(map(), User.t(), Account.t()) :: {:ok, Receipt.t()} | {:error, term()}
  def upload(file_params, user, account) do
    with {:ok, file_path} <- store_file(file_params),
         {:ok, file_hash} <- compute_hash(file_path),
         :ok <- check_duplicate(file_hash, account.id),
         {:ok, receipt} <- create_receipt(file_path, file_hash, user, account) do

      # Queue background processing
      %{receipt_id: receipt.id}
      |> ReceiptProcessingWorker.new()
      |> Oban.insert()

      {:ok, receipt}
    end
  end

  @doc """
  Matches extracted items to grocery catalog.
  """
  @spec match_items(Receipt.t()) :: {:ok, Receipt.t()}
  def match_items(receipt) do
    receipt = Ash.load!(receipt, :items)

    for item <- receipt.items do
      match = find_best_match(item.raw_name, receipt.account_id)
      update_item_match(item, match)
    end

    {:ok, Ash.load!(receipt, :items)}
  end

  @doc """
  Creates inventory entries from confirmed receipt items.
  """
  @spec create_inventory_entries(Receipt.t(), map()) :: {:ok, [InventoryEntry.t()]}
  def create_inventory_entries(receipt, options \\ %{}) do
    storage_location_id = options[:storage_location_id]

    receipt.items
    |> Enum.filter(& &1.status == :confirmed)
    |> Enum.map(&create_entry_from_item(&1, storage_location_id))
  end
end
```

**Oban Worker:**

```elixir
defmodule GroceryPlanner.Workers.ReceiptProcessingWorker do
  use Oban.Worker, queue: :ai_jobs, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"receipt_id" => receipt_id}}) do
    receipt = Inventory.get_receipt!(receipt_id)

    with {:ok, receipt} <- update_status(receipt, :processing),
         {:ok, extraction} <- call_extraction_service(receipt),
         {:ok, receipt} <- save_extraction_results(receipt, extraction),
         {:ok, receipt} <- ReceiptProcessor.match_items(receipt) do

      update_status(receipt, :completed)
      broadcast_completion(receipt)
      :ok
    else
      {:error, reason} ->
        update_status(receipt, :failed, reason)
        {:error, reason}
    end
  end
end
```

### Item Matching Strategy

```elixir
defmodule GroceryPlanner.Inventory.ItemMatcher do
  @moduledoc """
  Matches extracted receipt items to existing grocery catalog.
  """

  @doc """
  Finds the best matching GroceryItem for extracted text.
  Uses multiple strategies in order of preference.
  """
  def find_best_match(extracted_name, account_id) do
    strategies = [
      &exact_match/2,
      &normalized_match/2,
      &fuzzy_match/2,
      &semantic_match/2
    ]

    Enum.find_value(strategies, fn strategy ->
      case strategy.(extracted_name, account_id) do
        {:ok, match} when match.confidence > 0.7 -> match
        _ -> nil
      end
    end)
  end

  # Strategy 1: Exact case-insensitive match
  defp exact_match(name, account_id) do
    case Inventory.find_grocery_item_by_name(name, account_id) do
      nil -> {:no_match, nil}
      item -> {:ok, %{item: item, confidence: 1.0, strategy: :exact}}
    end
  end

  # Strategy 2: Normalized match (remove common abbreviations)
  defp normalized_match(name, account_id) do
    normalized = normalize_name(name)
    # ... implementation
  end

  # Strategy 3: Fuzzy string matching (Levenshtein distance)
  defp fuzzy_match(name, account_id) do
    items = Inventory.list_grocery_items(account_id)

    items
    |> Enum.map(fn item ->
      {item, String.jaro_distance(name, item.name)}
    end)
    |> Enum.max_by(fn {_, score} -> score end)
    |> case do
      {item, score} when score > 0.8 ->
        {:ok, %{item: item, confidence: score, strategy: :fuzzy}}
      _ ->
        {:no_match, nil}
    end
  end

  # Strategy 4: Semantic matching using embeddings
  defp semantic_match(name, account_id) do
    # Uses AI-002 embeddings if available
    # ... implementation
  end
end
```

## UI/UX Specifications

### Upload Flow

**Step 1: Upload Screen**
```heex
<div class="flex flex-col items-center gap-6 p-8">
  <div
    class="border-2 border-dashed border-base-300 rounded-xl p-12 text-center hover:border-primary transition-colors cursor-pointer"
    phx-drop-target={@uploads.receipt.ref}
  >
    <.icon name="hero-camera" class="w-16 h-16 mx-auto text-base-content/50 mb-4" />
    <h3 class="text-lg font-medium mb-2">Upload Receipt</h3>
    <p class="text-base-content/70 mb-4">
      Drag & drop or click to select
    </p>
    <.live_file_input upload={@uploads.receipt} class="hidden" />
    <button type="button" class="btn btn-primary" onclick="document.querySelector('input[type=file]').click()">
      Choose File
    </button>
  </div>

  <p class="text-sm text-base-content/50">
    Supports JPEG, PNG, HEIC, PDF up to 10MB
  </p>
</div>
```

**Step 2: Processing Status**
```heex
<div class="flex flex-col items-center gap-4 p-8">
  <div class="radial-progress text-primary" style={"--value:#{@progress}"}>
    <%= @progress %>%
  </div>
  <p class="text-lg"><%= @status_message %></p>
  <ul class="steps steps-vertical">
    <li class={step_class(:upload, @current_step)}>Uploading</li>
    <li class={step_class(:ocr, @current_step)}>Reading text</li>
    <li class={step_class(:extract, @current_step)}>Extracting items</li>
    <li class={step_class(:match, @current_step)}>Matching to catalog</li>
  </ul>
</div>
```

**Step 3: Review & Confirm**
```heex
<div class="space-y-6">
  <!-- Receipt Summary -->
  <div class="bg-base-200 rounded-xl p-4">
    <div class="flex justify-between items-center">
      <div>
        <p class="font-medium"><%= @receipt.merchant_name || "Unknown Store" %></p>
        <p class="text-sm text-base-content/70">
          <%= Calendar.strftime(@receipt.purchase_date, "%B %d, %Y") %>
        </p>
      </div>
      <div class="text-right">
        <p class="font-medium text-lg">
          <%= Money.to_string(@receipt.total_amount) %>
        </p>
        <p class="text-sm text-base-content/70">
          <%= length(@receipt.items) %> items
        </p>
      </div>
    </div>
  </div>

  <!-- Items List -->
  <div class="space-y-2">
    <%= for item <- @receipt.items do %>
      <div class="bg-base-100 rounded-lg p-4 border border-base-300">
        <div class="flex items-start gap-4">
          <!-- Confidence indicator -->
          <div class={["w-2 h-full rounded-full", confidence_color(item.confidence)]}></div>

          <!-- Item details (editable) -->
          <div class="flex-1 grid grid-cols-12 gap-2">
            <div class="col-span-5">
              <input
                type="text"
                value={item.final_name || item.parsed_name}
                class="input input-sm input-bordered w-full"
                phx-blur="update_item_name"
                phx-value-id={item.id}
              />
            </div>
            <div class="col-span-2">
              <input
                type="number"
                value={item.quantity}
                class="input input-sm input-bordered w-full"
                phx-blur="update_item_quantity"
                phx-value-id={item.id}
              />
            </div>
            <div class="col-span-2">
              <input
                type="text"
                value={item.unit}
                class="input input-sm input-bordered w-full"
                phx-blur="update_item_unit"
                phx-value-id={item.id}
              />
            </div>
            <div class="col-span-2">
              <input
                type="text"
                value={Money.to_string(item.total_price)}
                class="input input-sm input-bordered w-full"
                disabled
              />
            </div>
            <div class="col-span-1">
              <button
                type="button"
                class="btn btn-ghost btn-sm btn-square"
                phx-click="remove_item"
                phx-value-id={item.id}
              >
                <.icon name="hero-trash" class="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>

        <!-- Catalog match -->
        <%= if item.grocery_item do %>
          <div class="mt-2 flex items-center gap-2 text-sm">
            <span class="text-base-content/70">Matched to:</span>
            <span class="badge badge-success badge-sm"><%= item.grocery_item.name %></span>
            <button type="button" class="link link-primary text-xs" phx-click="change_match" phx-value-id={item.id}>
              Change
            </button>
          </div>
        <% else %>
          <div class="mt-2 flex items-center gap-2 text-sm">
            <span class="text-warning">No match found</span>
            <button type="button" class="link link-primary text-xs" phx-click="find_match" phx-value-id={item.id}>
              Find match
            </button>
            <button type="button" class="link link-primary text-xs" phx-click="create_new" phx-value-id={item.id}>
              Create new item
            </button>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>

  <!-- Actions -->
  <div class="flex justify-between items-center pt-4">
    <button type="button" class="btn btn-ghost" phx-click="cancel">
      Cancel
    </button>
    <div class="flex gap-2">
      <button type="button" class="btn btn-outline" phx-click="add_item">
        <.icon name="hero-plus" class="w-4 h-4" /> Add Item
      </button>
      <button type="button" class="btn btn-primary" phx-click="confirm_import">
        Add <%= length(@confirmed_items) %> Items to Inventory
      </button>
    </div>
  </div>
</div>
```

### Mobile Considerations

- Camera capture button prominent on mobile
- Swipe to delete items
- Bottom sheet for item editing
- Haptic feedback on confirmations

## Testing Strategy

### Unit Tests

```elixir
defmodule GroceryPlanner.Inventory.ReceiptProcessorTest do
  use GroceryPlanner.DataCase

  describe "upload/3" do
    test "stores file and creates receipt record" do
      file = fixture_file("receipt.jpg")
      assert {:ok, receipt} = ReceiptProcessor.upload(file, user, account)
      assert receipt.status == :pending
      assert receipt.file_path != nil
    end

    test "detects duplicate receipts" do
      file = fixture_file("receipt.jpg")
      {:ok, _} = ReceiptProcessor.upload(file, user, account)

      assert {:error, :duplicate_receipt} =
        ReceiptProcessor.upload(file, user, account)
    end
  end
end
```

### Integration Tests

```python
def test_extract_receipt():
    with open("test_receipts/whole_foods.jpg", "rb") as f:
        files = {"image": f}
        response = client.post("/api/v1/receipts/extract", files=files)

    assert response.status_code == 200
    data = response.json()
    assert data["extraction"]["merchant"]["name"] is not None
    assert len(data["extraction"]["line_items"]) > 0
```

### OCR Golden Tests

| Receipt Type | Expected Items | Min Accuracy |
|--------------|----------------|--------------|
| Whole Foods (clear) | 15 items | 90% |
| Walmart (thermal) | 20 items | 85% |
| Target (color) | 12 items | 88% |
| Costco (long) | 30 items | 85% |
| Crumpled receipt | 10 items | 70% |

## Dependencies

### Python Service
- `pytesseract>=0.3.10`
- `tesseract-ocr>=5.0.0` (system)
- `Pillow>=10.0.0`
- `transformers>=4.30.0` (for LayoutLM)
- `torch>=2.0.0`
- `opencv-python>=4.8.0`

### Elixir App
- `waffle` or custom file upload handling
- `oban` - background processing

## Configuration

### Environment Variables

```bash
# Elixir
RECEIPT_STORAGE_PATH=/app/uploads/receipts
RECEIPT_MAX_SIZE_MB=10
AI_SERVICE_URL=http://grocery-planner-ai.internal:8000
RECEIPT_PROCESSING_ENABLED=true

# Python
TESSERACT_PATH=/usr/bin/tesseract
OCR_MODEL=tesseract
LAYOUTLM_MODEL=microsoft/layoutlm-base-uncased
```

## Rollout Plan

1. **Phase 1:** File upload and storage infrastructure
2. **Phase 2:** Basic OCR extraction (Tesseract only)
3. **Phase 3:** Item matching and review UI
4. **Phase 4:** Inventory creation flow
5. **Phase 5:** Advanced extraction (LayoutLM)
6. **Phase 6:** Mobile camera optimization

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| OCR accuracy | > 85% | Correct items / total items |
| Processing time | < 10s | End-to-end extraction |
| User correction rate | < 20% | Corrections / total items |
| Completion rate | > 80% | Imports completed / started |
| Items per receipt | > 10 avg | Business metric |

## Open Questions

1. Should we support receipt email forwarding (parse email attachments)?
2. How long should we retain receipt images?
3. Should extracted prices update item price history?
4. Multi-language receipt support needed?

## Implementation Status

**Status: IN PROGRESS** (Phase 2 - Tesseract OCR + E2E testing complete)

### What's Built

#### Python OCR Service
- `POST /api/v1/extract-receipt` - Tesseract OCR fallback for receipt extraction
- `receipt_ocr.process_receipt()` - Direct Tesseract processing function
- `USE_TESSERACT_OCR` config flag (defaults to True)
- Three-way OCR selection: VLM → Tesseract → Mock

#### Elixir Integration
- `ReceiptLive` - 4-step wizard (upload → processing → review → complete)
- `ReceiptProcessor` - File storage, hash-based dedup, extraction result persistence
- `Changes.ProcessReceipt` - AshOban change for background OCR processing
- `AshOban.run_trigger/2` for immediate processing after upload
- Production bug fix: `authorize?: false` in handle_info for receipt processing

#### Test Coverage (40 tests)
- `test/grocery_planner_web/live/receipt_live_test.exs` - 29 E2E LiveView tests
- `python_service/tests/test_tesseract_ocr.py` - 11 Python Tesseract OCR tests

### What's Remaining
- US-002: Confidence indicators, "upload clearer image" option
- US-003: Item-to-catalog matching UI (ItemMatcher module exists)
- US-004: Purchase date, price, storage location, expiration dates
- US-005: "Proceed anyway" for duplicates, link to previous import
- Mobile camera capture optimization

## References

- [Tesseract OCR](https://github.com/tesseract-ocr/tesseract)
- [LayoutLM Paper](https://arxiv.org/abs/1912.13318)
- [AI Backlog - RCP-01](../docs/ai_backlog.md)
