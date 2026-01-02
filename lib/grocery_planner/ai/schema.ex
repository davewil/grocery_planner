defmodule GroceryPlanner.AI.Schema do
  @moduledoc """
  Defines the contract (request/response schemas) for interactions with the Python AI Service.
  """

  # Base struct for all requests
  defmodule Request do
    @moduledoc false
    @derive {Jason.Encoder,
             only: [:request_id, :tenant_id, :user_id, :feature, :payload, :metadata]}
    defstruct [:request_id, :tenant_id, :user_id, :feature, :payload, metadata: %{}]
  end

  # Base struct for all responses
  defmodule Response do
    @moduledoc false
    @derive {Jason.Encoder, only: [:request_id, :status, :payload, :error, :metadata]}
    defstruct [:request_id, :status, :payload, :error, :metadata]
  end

  # --- Feature: Smart Categorization ---

  defmodule CategorizationRequest do
    @moduledoc false
    @derive {Jason.Encoder, only: [:item_name, :candidate_labels]}
    defstruct [:item_name, :candidate_labels]
  end

  defmodule CategorizationResponse do
    @moduledoc false
    @derive {Jason.Encoder, only: [:category, :confidence]}
    defstruct [:category, :confidence]
  end

  # --- Feature: Receipt Extraction ---

  defmodule ExtractionRequest do
    @moduledoc false
    @derive {Jason.Encoder, only: [:image_url, :image_base64]}
    defstruct [:image_url, :image_base64]
  end

  defmodule ExtractionResponse do
    @moduledoc false
    @derive {Jason.Encoder, only: [:items, :total, :merchant, :date]}
    defstruct [:items, :total, :merchant, :date]
  end

  defmodule ExtractedItem do
    @moduledoc false
    @derive {Jason.Encoder, only: [:name, :quantity, :unit, :price, :confidence]}
    defstruct [:name, :quantity, :unit, :price, :confidence]
  end

  # --- Feature: Semantic Search ---

  defmodule EmbeddingRequest do
    @moduledoc false
    @derive {Jason.Encoder, only: [:text]}
    defstruct [:text]
  end

  defmodule EmbeddingResponse do
    @moduledoc false
    @derive {Jason.Encoder, only: [:vector]}
    defstruct [:vector]
  end

  # --- Feature: Optimization (Z3) ---

  defmodule OptimizationRequest do
    @moduledoc false
    @derive {Jason.Encoder, only: [:ingredients, :recipes, :constraints]}
    defstruct [:ingredients, :recipes, :constraints]
  end

  defmodule OptimizationResponse do
    @moduledoc false
    @derive {Jason.Encoder, only: [:selected_recipe_ids, :missing_ingredients, :explanation]}
    defstruct [:selected_recipe_ids, :missing_ingredients, :explanation]
  end

  # --- Feature: Chat ---

  defmodule ChatRequest do
    @moduledoc false
    @derive {Jason.Encoder, only: [:messages, :context]}
    defstruct [:messages, :context]
  end

  defmodule ChatMessage do
    @moduledoc false
    @derive {Jason.Encoder, only: [:role, :content]}
    defstruct [:role, :content]
  end

  defmodule ChatResponse do
    @moduledoc false
    @derive {Jason.Encoder, only: [:message, :tool_calls]}
    defstruct [:message, :tool_calls]
  end
end
