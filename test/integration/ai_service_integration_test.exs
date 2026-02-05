defmodule GroceryPlanner.Integration.AiServiceIntegrationTest do
  @moduledoc """
  Integration tests for categorization, embeddings, and live contract validation
  against the real Python AI service.

  These tests require the Python service to be running:

      AI_SERVICE_URL=http://localhost:8099 mix test.integration

  Or use: ./scripts/test-integration.sh
  """
  use GroceryPlanner.IntegrationCase, async: false

  alias GroceryPlanner.AiClient
  alias GroceryPlanner.AiClient.Contracts

  @moduletag :integration

  @context %{tenant_id: Ecto.UUID.generate(), user_id: Ecto.UUID.generate()}

  # ── Connectivity ────────────────────────────────────────────────

  describe "service connectivity" do
    test "health/ready endpoint returns ok with dependency checks" do
      assert service_healthy?(), "Python AI service not running at #{ai_service_url()}"

      {:ok, body} = AiClient.health_check()
      assert body["status"] in ["ok", "degraded"]
      assert is_map(body["checks"])
      assert Map.has_key?(body["checks"], "database")
    end

    test "health response validates against HealthCheckResponse contract" do
      assert service_healthy?()

      {:ok, body} = AiClient.health_check()
      assert {:ok, _validated} = Contracts.HealthCheckResponse.validate(body)
    end
  end

  # ── Categorization ──────────────────────────────────────────────

  describe "categorization" do
    test "categorizes a grocery item with candidate labels" do
      {:ok, body} =
        AiClient.categorize_item(
          "Organic Bananas",
          ["Produce", "Dairy", "Bakery", "Meat", "Frozen"],
          @context
        )

      assert body["status"] == "success"
      payload = body["payload"]
      assert is_binary(payload["category"])
      assert is_number(payload["confidence"])
      assert payload["confidence"] >= 0.0 and payload["confidence"] <= 1.0
      assert payload["confidence_level"] in ["high", "medium", "low"]
    end

    test "categorization response validates against CategorizationResponse contract" do
      {:ok, body} = AiClient.categorize_item("Milk", ["Dairy", "Produce", "Bakery"], @context)

      assert {:ok, validated} = Contracts.CategorizationResponse.validate(body["payload"])
      assert is_binary(validated.category)
      assert validated.confidence >= 0.0 and validated.confidence <= 1.0
    end

    test "categorization returns valid categories from candidate list" do
      candidates = ["Produce", "Dairy", "Bakery", "Meat"]

      {:ok, body} = AiClient.categorize_item("Whole Milk", candidates, @context)
      assert body["payload"]["category"] in candidates

      {:ok, body2} = AiClient.categorize_item("Fresh Broccoli", candidates, @context)
      assert body2["payload"]["category"] in candidates
    end

    test "batch categorization processes multiple items" do
      items = [
        %{id: "1", name: "Bananas"},
        %{id: "2", name: "Cheddar Cheese"},
        %{id: "3", name: "Sourdough Bread"}
      ]

      {:ok, body} =
        AiClient.categorize_batch(
          items,
          ["Produce", "Dairy", "Bakery", "Meat"],
          @context
        )

      assert body["status"] == "success"
      predictions = body["payload"]["predictions"]
      assert length(predictions) == 3

      for prediction <- predictions do
        assert prediction["id"] in ["1", "2", "3"]
        assert is_binary(prediction["predicted_category"])
        assert is_number(prediction["confidence"])
      end
    end

    test "batch categorization validates against BatchCategorizationResponse contract" do
      items = [%{id: "1", name: "Apples"}, %{id: "2", name: "Yogurt"}]

      {:ok, body} = AiClient.categorize_batch(items, ["Produce", "Dairy"], @context)

      assert {:ok, validated} = Contracts.BatchCategorizationResponse.validate(body["payload"])
      assert length(validated.predictions) == 2
    end
  end

  # ── Embeddings ──────────────────────────────────────────────────

  describe "embeddings" do
    test "generates embedding vector for a single text" do
      {:ok, body} = AiClient.generate_embedding("Organic Bananas", @context)

      assert body["status"] == "success"
      payload = body["payload"]
      assert is_binary(payload["model"])
      assert is_integer(payload["dimension"])
      assert payload["dimension"] > 0

      embeddings = payload["embeddings"]
      assert length(embeddings) == 1
      embedding = hd(embeddings)
      assert embedding["id"] == "1"
      assert is_list(embedding["vector"])
      assert length(embedding["vector"]) == payload["dimension"]
    end

    test "generates embeddings for multiple texts" do
      texts = [
        %{id: "a", text: "Fresh Bananas"},
        %{id: "b", text: "Whole Milk"},
        %{id: "c", text: "Rye Bread"}
      ]

      {:ok, body} = AiClient.generate_embeddings(texts, @context)

      assert body["status"] == "success"
      embeddings = body["payload"]["embeddings"]
      assert length(embeddings) == 3

      ids = Enum.map(embeddings, & &1["id"])
      assert "a" in ids
      assert "b" in ids
      assert "c" in ids
    end

    test "embedding response validates against EmbeddingResponse contract" do
      {:ok, body} = AiClient.generate_embedding("test text", @context)

      assert {:ok, validated} = Contracts.EmbeddingResponse.validate(body["payload"])
      assert is_binary(validated.model)
      assert validated.dimension > 0
    end

    test "embedding vectors have consistent dimensions across calls" do
      {:ok, body1} = AiClient.generate_embedding("Bananas", @context)
      {:ok, body2} = AiClient.generate_embedding("Milk", @context)

      dim1 = body1["payload"]["dimension"]
      dim2 = body2["payload"]["dimension"]
      assert dim1 == dim2, "Embedding dimensions should be consistent: #{dim1} vs #{dim2}"

      vec1 = hd(body1["payload"]["embeddings"])["vector"]
      vec2 = hd(body2["payload"]["embeddings"])["vector"]
      assert length(vec1) == dim1
      assert length(vec2) == dim2
    end

    test "batch embeddings with custom batch_size" do
      texts = Enum.map(1..5, &%{id: "#{&1}", text: "Item #{&1}"})

      {:ok, body} = AiClient.generate_embeddings_batch(texts, @context, batch_size: 2)

      assert body["status"] == "success"
      assert length(body["payload"]["embeddings"]) == 5
    end
  end

  # ── Base Response Envelope ──────────────────────────────────────

  describe "response envelope contract" do
    test "categorization response has valid BaseResponse envelope" do
      {:ok, body} = AiClient.categorize_item("Milk", ["Dairy"], @context)

      assert {:ok, validated} = Contracts.BaseResponse.validate(body)
      assert validated.status == "success"
      assert is_binary(validated.request_id)
      assert is_map(validated.payload)
    end

    test "embedding response has valid BaseResponse envelope" do
      {:ok, body} = AiClient.generate_embedding("test", @context)

      assert {:ok, validated} = Contracts.BaseResponse.validate(body)
      assert validated.status == "success"
    end
  end

  # ── Error Handling ──────────────────────────────────────────────

  describe "error handling" do
    test "categorization with empty candidate labels" do
      result = AiClient.categorize_item("Milk", [], @context)

      case result do
        {:error, _} -> :ok
        {:ok, body} -> assert is_map(body)
      end
    end

    test "embedding with empty text list" do
      result = AiClient.generate_embeddings([], @context)

      case result do
        {:ok, body} ->
          assert body["status"] == "success"
          assert body["payload"]["embeddings"] == []

        {:error, _} ->
          :ok
      end
    end
  end
end
