defmodule GroceryPlanner.AI.EmbeddingModel do
  @moduledoc """
  Custom embedding model for AshAi that uses the GroceryPlanner Python service.

  Uses the all-MiniLM-L6-v2 model (384 dimensions) for generating text embeddings.
  """
  use AshAi.EmbeddingModel

  alias GroceryPlanner.AiClient

  @impl true
  def dimensions(_opts), do: 384

  @impl true
  def generate(texts, _opts) when is_list(texts) do
    # Convert texts to the format expected by AiClient
    indexed_texts =
      texts
      |> Enum.with_index()
      |> Enum.map(fn {text, idx} -> %{id: to_string(idx), text: text} end)

    context = %{
      tenant_id: "system",
      user_id: "system"
    }

    case AiClient.generate_embeddings(indexed_texts, context, []) do
      {:ok, %{"embeddings" => embeddings}} ->
        # Sort by ID to maintain order and extract vectors
        vectors =
          embeddings
          |> Enum.sort_by(fn e -> String.to_integer(e["id"]) end)
          |> Enum.map(fn e -> e["vector"] end)

        {:ok, vectors}

      {:ok, %{embeddings: embeddings}} ->
        vectors =
          embeddings
          |> Enum.sort_by(fn e -> String.to_integer(to_string(e.id)) end)
          |> Enum.map(fn e -> e.vector end)

        {:ok, vectors}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
