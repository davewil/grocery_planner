defmodule GroceryPlanner.AiClient do
  @moduledoc """
  Client for the GroceryPlanner AI Python Service.

  Handles communication with the sidecar service for:
  - Categorization
  - Receipt Extraction
  - Embeddings
  - Async Job Management
  """

  require Logger

  @default_url "http://localhost:8000"

  @doc """
  Predicts the category for a grocery item.
  """
  def categorize_item(item_name, candidate_labels, context, opts \\ []) do
    payload = %{
      item_name: item_name,
      candidate_labels: candidate_labels
    }

    post("/api/v1/categorize", payload, "categorization", context, opts)
  end

  @doc """
  Predicts categories for a batch of grocery items.
  """
  def categorize_batch(items, candidate_labels, context, opts \\ []) do
    payload = %{
      items: items,
      candidate_labels: candidate_labels
    }

    post("/api/v1/categorize-batch", payload, "categorization_batch", context, opts)
  end

  @doc """
  Extracts items from a receipt image (Base64).
  """
  def extract_receipt(image_base64, context, opts \\ []) do
    payload = %{
      image_base64: image_base64
    }

    post("/api/v1/extract-receipt", payload, "extraction", context, opts)
  end

  @doc """
  Generates an embedding for the given text.
  Wraps the text in the batch format expected by the Python service.
  """
  def generate_embedding(text, context, opts \\ []) do
    generate_embeddings([%{id: "1", text: text}], context, opts)
  end

  @doc """
  Generates embeddings for the given texts.
  Each text should be a map with :id and :text keys.
  """
  def generate_embeddings(texts, context, opts \\ []) do
    payload = %{
      texts: texts
    }

    post("/api/v1/embed", payload, "embedding", context, opts)
  end

  @doc """
  Generates embeddings for a batch of texts with configurable batch size.
  Each text should be a map with :id and :text keys.
  """
  def generate_embeddings_batch(texts, context, opts \\ []) do
    payload = %{
      texts: texts,
      batch_size: Keyword.get(opts, :batch_size, 32)
    }

    post("/api/v1/embed-batch", payload, "embedding_batch", context, opts)
  end

  @doc """
  Submits a background job to the AI service.
  """
  def submit_job(feature, payload, context, opts \\ []) do
    request_body = %{
      tenant_id: context.tenant_id,
      user_id: context.user_id,
      feature: feature,
      payload: payload
    }

    Req.post(client(opts), url: "/api/v1/jobs", json: request_body)
    |> handle_response()
  end

  @doc """
  Gets the status of a background job.
  """
  def get_job(job_id, context, opts \\ []) do
    Req.get(client(opts),
      url: "/api/v1/jobs/#{job_id}",
      headers: [{"x-tenant-id", context.tenant_id}]
    )
    |> handle_response()
  end

  # --- Internal Helpers ---

  defp post(url, payload, feature, context, opts) do
    request_body = %{
      request_id: "req_#{Ecto.UUID.generate()}",
      tenant_id: context.tenant_id,
      user_id: context.user_id,
      feature: feature,
      payload: payload
    }

    Req.post(client(opts), url: url, json: request_body)
    |> handle_response()
  end

  defp client(opts) do
    base_url = System.get_env("AI_SERVICE_URL") || @default_url

    Req.new(base_url: base_url)
    |> Req.Request.put_header("content-type", "application/json")
    # Set a reasonable timeout for AI operations (5s default, maybe more needed)
    |> Req.Request.put_option(:receive_timeout, 10_000)
    |> Req.merge(opts)
  end

  defp handle_response({:ok, %Req.Response{status: 200, body: body}}) do
    {:ok, body}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) do
    Logger.error("AI Service Error (#{status}): #{inspect(body)}")
    {:error, body}
  end

  defp handle_response({:error, reason}) do
    Logger.error("AI Service Connection Error: #{inspect(reason)}")
    {:error, reason}
  end
end
