# AI-001: Smart Item Categorization

## Overview

**Feature:** Automatic category prediction for grocery items using Zero-Shot Text Classification
**Priority:** High
**Epic:** AIP-01 (AI Platform Foundation)
**Estimated Effort:** 3-5 days

## Problem Statement

When creating a new grocery item, users must manually select a category from a dropdown list. This creates friction in the item creation flow and can lead to inconsistent categorization across the household.

**Current Pain Points:**
- Manual category selection slows down item entry
- Users may categorize items inconsistently
- New users don't know which categories exist
- Bulk imports require manual category assignment

## User Stories

### US-001: Auto-suggest category on item creation
**As a** user creating a new grocery item
**I want** the system to suggest a category based on the item name
**So that** I can quickly accept the suggestion or override it

**Acceptance Criteria:**
- [x] When user types an item name, system suggests a category
- [x] Suggestion appears within 500ms of user stopping typing (debounced)
- [x] User can accept suggestion with one click/tap
- [x] User can override suggestion by selecting different category
- [x] Suggestion includes confidence indicator (high/medium/low)
- [x] Works offline with graceful degradation (no suggestion shown)

### US-002: Batch categorization for imports
**As a** user importing items from a receipt or CSV
**I want** all items to be auto-categorized
**So that** I don't have to manually assign categories to each item

**Acceptance Criteria:**
- [x] Batch endpoint accepts array of item names
- [x] Returns category predictions for all items in single response
- [x] Processing time < 2 seconds for up to 50 items
- [x] Each prediction includes confidence score
- [x] Low-confidence items flagged for user review

### US-003: Learn from corrections
**As a** system administrator
**I want** user corrections to be recorded
**So that** we can improve categorization accuracy over time

**Acceptance Criteria:**
- [x] When user overrides a suggestion, correction is logged
- [x] Logs include: original prediction, user correction, item name, confidence
- [x] Corrections are tenant-scoped for privacy
- [x] Data can be exported for model fine-tuning

## Technical Specification

### Architecture

```
┌─────────────────┐     HTTP/JSON      ┌──────────────────┐
│  Elixir/Phoenix │ ◄────────────────► │  Python/FastAPI  │
│   (LiveView)    │                    │   (AI Service)   │
└─────────────────┘                    └──────────────────┘
        │                                       │
        │                                       │
        ▼                                       ▼
┌─────────────────┐                    ┌──────────────────┐
│   PostgreSQL    │                    │  Hugging Face    │
│   (Ash/Ecto)    │                    │  Transformers    │
└─────────────────┘                    └──────────────────┘
```

### Python Service Endpoint

**Endpoint:** `POST /api/v1/categorize`

**Request Schema:**
```json
{
  "version": "1.0",
  "request_id": "uuid",
  "account_id": "uuid",
  "items": [
    {
      "id": "temp-1",
      "name": "Organic whole milk"
    }
  ],
  "candidate_labels": [
    "Dairy",
    "Produce",
    "Meat & Seafood",
    "Bakery",
    "Frozen",
    "Pantry",
    "Beverages",
    "Snacks",
    "Household",
    "Other"
  ]
}
```

**Response Schema:**
```json
{
  "version": "1.0",
  "request_id": "uuid",
  "processing_time_ms": 145,
  "predictions": [
    {
      "id": "temp-1",
      "name": "Organic whole milk",
      "predicted_category": "Dairy",
      "confidence": 0.94,
      "confidence_level": "high",
      "all_scores": {
        "Dairy": 0.94,
        "Beverages": 0.03,
        "Produce": 0.01
      }
    }
  ]
}
```

**Confidence Levels:**
- `high`: confidence >= 0.80
- `medium`: confidence >= 0.50 and < 0.80
- `low`: confidence < 0.50

### Model Selection

**Primary Model:** `facebook/bart-large-mnli`
- Zero-shot classification
- No training data required
- Supports custom label sets

**Alternative Models:**
- `MoritzLaworst/DeBERTa-v3-base-mnli-fever-anli` (faster, slightly less accurate)
- Fine-tuned model on grocery data (future enhancement)

### Elixir Integration

**Module:** `GroceryPlanner.AI.Categorizer`

```elixir
defmodule GroceryPlanner.AI.Categorizer do
  @moduledoc """
  Client for the AI categorization service.
  """

  @doc """
  Predicts the category for a single item name.
  Returns {:ok, prediction} or {:error, reason}.
  """
  @spec predict(String.t(), Keyword.t()) ::
    {:ok, %{category: String.t(), confidence: float()}} | {:error, term()}
  def predict(item_name, opts \\ [])

  @doc """
  Predicts categories for multiple items in batch.
  """
  @spec predict_batch([String.t()], Keyword.t()) ::
    {:ok, [%{name: String.t(), category: String.t(), confidence: float()}]} | {:error, term()}
  def predict_batch(item_names, opts \\ [])
end
```

### LiveView Integration

**Event Flow:**
1. User types item name in form field
2. `phx-debounce="500"` triggers `suggest_category` event
3. LiveView calls `AI.Categorizer.predict/2`
4. Suggestion displayed below category dropdown
5. User clicks suggestion to populate dropdown

**Template:**
```heex
<.input
  field={@form[:name]}
  label="Item Name"
  phx-debounce="500"
  phx-change="suggest_category"
/>

<.input
  field={@form[:category_id]}
  type="select"
  label="Category"
  options={@category_options}
/>

<%= if @category_suggestion do %>
  <div class="mt-1 flex items-center gap-2">
    <span class="text-sm text-base-content/70">Suggested:</span>
    <button
      type="button"
      class="badge badge-primary cursor-pointer"
      phx-click="accept_category_suggestion"
    >
      <%= @category_suggestion.name %>
    </button>
    <span class={[
      "badge badge-sm",
      confidence_badge_class(@category_suggestion.confidence_level)
    ]}>
      <%= @category_suggestion.confidence_level %>
    </span>
  </div>
<% end %>
```

### Database Schema

**Correction Logging Table:** `ai_categorization_feedback`

```elixir
defmodule GroceryPlanner.Repo.Migrations.AddAiCategorizationFeedback do
  use Ecto.Migration

  def change do
    create table(:ai_categorization_feedback, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :account_id, references(:accounts, type: :uuid, on_delete: :delete_all), null: false
      add :item_name, :string, null: false
      add :predicted_category, :string, null: false
      add :predicted_confidence, :float, null: false
      add :user_selected_category, :string, null: false
      add :was_correction, :boolean, default: false
      add :model_version, :string

      timestamps(type: :utc_datetime)
    end

    create index(:ai_categorization_feedback, [:account_id])
    create index(:ai_categorization_feedback, [:was_correction])
  end
end
```

## UI/UX Specifications

### Visual Design

**Suggestion Chip:**
- Appears below category dropdown
- Primary color badge for category name
- Secondary badge showing confidence level
- Hover state indicates clickability

**Confidence Indicators:**
| Level | Color | Icon |
|-------|-------|------|
| High | `badge-success` | checkmark |
| Medium | `badge-warning` | question mark |
| Low | `badge-ghost` | none |

### Loading States

- Skeleton pulse on suggestion area while AI is processing
- "Analyzing..." text with spinner
- Graceful timeout after 3 seconds (hide suggestion area)

### Error Handling

- Network errors: silently fail, no suggestion shown
- Service unavailable: no suggestion, no error message to user
- Invalid response: log error, no suggestion shown

## Testing Strategy

### Unit Tests (Elixir)

```elixir
defmodule GroceryPlanner.AI.CategorizerTest do
  use GroceryPlanner.DataCase

  describe "predict/2" do
    test "returns category prediction for valid item name" do
      # Mock HTTP response
      assert {:ok, %{category: "Dairy", confidence: _}} =
        Categorizer.predict("whole milk")
    end

    test "returns error when service unavailable" do
      # Mock timeout
      assert {:error, :timeout} = Categorizer.predict("milk")
    end
  end
end
```

### Integration Tests (Python)

```python
def test_categorize_single_item():
    response = client.post("/api/v1/categorize", json={
        "version": "1.0",
        "request_id": str(uuid.uuid4()),
        "account_id": str(uuid.uuid4()),
        "items": [{"id": "1", "name": "Organic whole milk"}],
        "candidate_labels": ["Dairy", "Produce", "Meat"]
    })
    assert response.status_code == 200
    data = response.json()
    assert data["predictions"][0]["predicted_category"] == "Dairy"
    assert data["predictions"][0]["confidence"] > 0.8
```

### Golden Test Cases

| Item Name | Expected Category | Min Confidence |
|-----------|-------------------|----------------|
| "whole milk" | Dairy | 0.85 |
| "chicken breast" | Meat & Seafood | 0.85 |
| "bananas" | Produce | 0.90 |
| "sourdough bread" | Bakery | 0.80 |
| "frozen pizza" | Frozen | 0.80 |
| "olive oil" | Pantry | 0.75 |
| "orange juice" | Beverages | 0.80 |
| "potato chips" | Snacks | 0.80 |
| "dish soap" | Household | 0.85 |

## Dependencies

### Python Service
- `transformers>=4.30.0`
- `torch>=2.0.0`
- `fastapi>=0.100.0`
- `uvicorn>=0.22.0`

### Elixir App
- `req` (HTTP client) - already installed
- `jason` (JSON) - already installed

## Configuration

### Environment Variables

```bash
# Elixir
AI_SERVICE_URL=http://grocery-planner-ai.internal:8000
AI_SERVICE_TIMEOUT_MS=3000
AI_CATEGORIZATION_ENABLED=true

# Python
MODEL_NAME=facebook/bart-large-mnli
MODEL_CACHE_DIR=/app/models
MAX_BATCH_SIZE=50
```

### Feature Flag

```elixir
# config/runtime.exs
config :grocery_planner, :features,
  ai_categorization: System.get_env("AI_CATEGORIZATION_ENABLED", "false") == "true"
```

## Rollout Plan

1. **Phase 1:** Deploy Python service with categorization endpoint
2. **Phase 2:** Add Elixir client module with feature flag (disabled)
3. **Phase 3:** Enable for internal testing
4. **Phase 4:** Enable for all users
5. **Phase 5:** Add feedback collection and monitoring

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Suggestion acceptance rate | > 70% | Clicks on suggestion / suggestions shown |
| Prediction accuracy | > 85% | Correct predictions / total predictions |
| Response time (p95) | < 500ms | AI service latency |
| User correction rate | < 15% | Corrections / suggestions shown |

## Open Questions

1. Should we cache predictions for common item names?
2. Should category labels be dynamic (from user's categories) or fixed?
3. How long should we retain feedback data?

## Implementation Status

**Status: COMPLETE** (all 3 user stories implemented and tested)

### Elixir Modules
- `GroceryPlanner.AI.Categorizer` - Single and batch prediction client with confidence levels
- `GroceryPlanner.AI.CategorizationFeedback` - Ash Resource for correction logging (multitenanted)
- `GroceryPlanner.AiClient` - HTTP client for Python AI service
- LiveView integration in `InventoryLive` with debounced auto-suggest and accept/override flow

### Python Service
- `POST /api/v1/categorize` - Single item categorization
- `POST /api/v1/categorize-batch` - Batch categorization (up to 50 items)

### Test Coverage (56 tests)
- `test/grocery_planner/ai/categorizer_test.exs` - 13 tests (confidence levels, predict, predict_batch success/error/disabled/batch_too_large)
- `test/grocery_planner/ai/categorization_feedback_test.exs` - 13 tests (log_correction, corrections_only, list_for_export, CRUD, multitenancy)
- `test/grocery_planner_web/live/inventory_live_categorization_test.exs` - 14 tests (suggest_category, accept_suggestion, auto-categorization, confidence badges)
- `test/grocery_planner/ai/embeddings_test.exs` - 11 tests (shared AI infrastructure)
- `test/grocery_planner/ai_client_test.exs` - 5 tests (HTTP client wrapper)

### Feature Flag
- Controlled via `config :grocery_planner, :features, ai_categorization: true/false`
- Graceful degradation when disabled (no suggestion shown, no errors)

### Design Decisions
- Category labels are dynamic (from user's categories), not fixed - enables per-account customization
- Feedback data retained indefinitely for model fine-tuning potential
- Predictions not cached (low latency from sidecar service makes caching unnecessary)

## References

- [Hugging Face Zero-Shot Classification](https://huggingface.co/tasks/zero-shot-classification)
- [BART-MNLI Model Card](https://huggingface.co/facebook/bart-large-mnli)
- [AI Integration Plan](../docs/ai_integration_plan.md)
