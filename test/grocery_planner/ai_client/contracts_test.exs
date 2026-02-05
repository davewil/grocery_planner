defmodule GroceryPlanner.AiClient.ContractsTest do
  use ExUnit.Case, async: true

  alias GroceryPlanner.AiClient.Contracts.CategorizationResponse
  alias GroceryPlanner.AiClient.Contracts.ExtractionResponse
  alias GroceryPlanner.AiClient.Contracts.HealthResponse

  describe "CategorizationResponse.validate/1" do
    test "validates a well-formed categorization response" do
      data = %{
        "category" => "Produce",
        "confidence" => 0.95,
        "confidence_level" => "high",
        "all_scores" => %{"Produce" => 0.95, "Dairy" => 0.03, "Bakery" => 0.02},
        "processing_time_ms" => 12.5
      }

      assert {:ok, validated} = CategorizationResponse.validate(data)
      assert validated.category == "Produce"
      assert validated.confidence == 0.95
      assert validated.confidence_level == "high"
    end

    test "validates with only required fields" do
      data = %{"category" => "Dairy", "confidence" => 0.8}

      assert {:ok, validated} = CategorizationResponse.validate(data)
      assert validated.category == "Dairy"
      assert validated.confidence == 0.8
      assert validated.confidence_level == nil
    end

    test "rejects missing category" do
      data = %{"confidence" => 0.8}

      assert {:error, changeset} = CategorizationResponse.validate(data)
      assert "can't be blank" in errors_on(changeset).category
    end

    test "rejects missing confidence" do
      data = %{"category" => "Produce"}

      assert {:error, changeset} = CategorizationResponse.validate(data)
      assert "can't be blank" in errors_on(changeset).confidence
    end

    test "rejects confidence below 0" do
      data = %{"category" => "Produce", "confidence" => -0.1}

      assert {:error, changeset} = CategorizationResponse.validate(data)
      assert length(changeset.errors) > 0
    end

    test "rejects confidence above 1" do
      data = %{"category" => "Produce", "confidence" => 1.5}

      assert {:error, changeset} = CategorizationResponse.validate(data)
      assert length(changeset.errors) > 0
    end

    test "rejects invalid confidence_level" do
      data = %{"category" => "Produce", "confidence" => 0.8, "confidence_level" => "very_high"}

      assert {:error, changeset} = CategorizationResponse.validate(data)
      assert length(changeset.errors) > 0
    end

    test "accepts boundary confidence values" do
      assert {:ok, _} =
               CategorizationResponse.validate(%{"category" => "A", "confidence" => 0.0})

      assert {:ok, _} =
               CategorizationResponse.validate(%{"category" => "A", "confidence" => 1.0})
    end

    test "accepts all valid confidence levels" do
      for level <- ["high", "medium", "low"] do
        data = %{"category" => "Produce", "confidence" => 0.5, "confidence_level" => level}
        assert {:ok, _} = CategorizationResponse.validate(data)
      end
    end
  end

  describe "ExtractionResponse.validate/1" do
    test "validates a well-formed extraction response" do
      data = %{
        "items" => [
          %{"name" => "Bananas", "quantity" => 1.0, "price" => 1.99},
          %{"name" => "Milk", "quantity" => 1.0, "price" => 3.49}
        ],
        "total" => 5.48,
        "merchant" => "Test Store",
        "date" => "2026-01-15"
      }

      assert {:ok, validated} = ExtractionResponse.validate(data)
      assert length(validated.items) == 2
      assert validated.total == 5.48
      assert validated.merchant == "Test Store"
    end

    test "validates with only required fields" do
      data = %{"items" => [%{"name" => "Apple"}]}

      assert {:ok, validated} = ExtractionResponse.validate(data)
      assert length(validated.items) == 1
      assert validated.merchant == nil
    end

    test "rejects missing items" do
      data = %{"total" => 5.48}

      assert {:error, changeset} = ExtractionResponse.validate(data)
      assert "can't be blank" in errors_on(changeset).items
    end

    test "rejects items without name field" do
      data = %{"items" => [%{"quantity" => 1.0, "price" => 2.99}]}

      assert {:error, changeset} = ExtractionResponse.validate(data)
      assert length(changeset.errors) > 0
    end

    test "accepts empty items list" do
      data = %{"items" => []}

      assert {:ok, validated} = ExtractionResponse.validate(data)
      assert validated.items == []
    end
  end

  describe "HealthResponse.validate/1" do
    test "validates a well-formed health response" do
      data = %{
        "status" => "ok",
        "checks" => %{
          "database" => %{"status" => "ok"},
          "classifier" => %{"status" => "not_loaded"}
        },
        "version" => "1.0.0"
      }

      assert {:ok, validated} = HealthResponse.validate(data)
      assert validated.status == "ok"
      assert validated.version == "1.0.0"
    end

    test "accepts degraded status" do
      data = %{"status" => "degraded", "checks" => %{}, "version" => "1.0.0"}

      assert {:ok, validated} = HealthResponse.validate(data)
      assert validated.status == "degraded"
    end

    test "accepts error status" do
      data = %{"status" => "error", "checks" => %{}, "version" => "1.0.0"}

      assert {:ok, validated} = HealthResponse.validate(data)
      assert validated.status == "error"
    end

    test "rejects invalid status" do
      data = %{"status" => "unknown", "checks" => %{}, "version" => "1.0.0"}

      assert {:error, changeset} = HealthResponse.validate(data)
      assert length(changeset.errors) > 0
    end

    test "rejects missing status" do
      data = %{"checks" => %{}, "version" => "1.0.0"}

      assert {:error, changeset} = HealthResponse.validate(data)
      assert "can't be blank" in errors_on(changeset).status
    end

    test "rejects missing version" do
      data = %{"status" => "ok", "checks" => %{}}

      assert {:error, changeset} = HealthResponse.validate(data)
      assert "can't be blank" in errors_on(changeset).version
    end
  end

  # Helper to extract error messages from changeset
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
