defmodule GroceryPlanner.AiClient.ContractsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias GroceryPlanner.AiClient.Contracts.{
    BaseResponse,
    CategorizationResponse,
    BatchCategorizationResponse,
    BatchPrediction,
    ReceiptExtractionResponse,
    ReceiptLineItem,
    EmbeddingResponse,
    EmbeddingEntry,
    HealthCheckResponse,
    MealOptimizationResponse,
    MealPlanEntry,
    QuickSuggestionResponse,
    QuickSuggestionEntry
  }

  # ── Generators ──────────────────────────────────────────────────────

  defp confidence_gen, do: StreamData.float(min: 0.0, max: 1.0)

  defp confidence_level_gen, do: StreamData.member_of(["high", "medium", "low"])

  defp category_gen,
    do: StreamData.member_of(["Produce", "Dairy", "Bakery", "Meat", "Frozen", "Snacks"])

  defp non_empty_string, do: StreamData.string(:alphanumeric, min_length: 1, max_length: 50)

  defp uuid_gen, do: StreamData.map(StreamData.constant(nil), fn _ -> Ecto.UUID.generate() end)

  defp positive_float, do: StreamData.float(min: 0.1, max: 10000.0)

  # ── BaseResponse ────────────────────────────────────────────────────

  describe "BaseResponse" do
    test "validates a successful response envelope" do
      data = %{
        "request_id" => "req_abc123",
        "status" => "success",
        "payload" => %{"category" => "Produce"},
        "error" => nil,
        "metadata" => %{}
      }

      assert {:ok, result} = BaseResponse.validate(data)
      assert result.request_id == "req_abc123"
      assert result.status == "success"
    end

    test "validates an error response envelope" do
      data = %{
        "request_id" => "req_abc123",
        "status" => "error",
        "payload" => nil,
        "error" => "Model not loaded"
      }

      assert {:ok, result} = BaseResponse.validate(data)
      assert result.status == "error"
      assert result.error == "Model not loaded"
    end

    test "rejects missing request_id" do
      data = %{"status" => "success", "payload" => %{}}
      assert {:error, changeset} = BaseResponse.validate(data)
      assert "can't be blank" in errors_on(changeset, :request_id)
    end

    test "rejects invalid status" do
      data = %{"request_id" => "req_1", "status" => "unknown", "payload" => %{}}
      assert {:error, changeset} = BaseResponse.validate(data)
      assert "is invalid" in errors_on(changeset, :status)
    end

    test "rejects non-map input" do
      assert {:error, :not_a_map} = BaseResponse.validate("not a map")
      assert {:error, :not_a_map} = BaseResponse.validate(nil)
      assert {:error, :not_a_map} = BaseResponse.validate(42)
    end
  end

  # ── CategorizationResponse ──────────────────────────────────────────

  describe "CategorizationResponse" do
    test "validates a complete categorization payload" do
      data = %{
        "category" => "Produce",
        "confidence" => 0.95,
        "confidence_level" => "high",
        "all_scores" => %{"Produce" => 0.95, "Dairy" => 0.03, "Bakery" => 0.02},
        "processing_time_ms" => 12.5
      }

      assert {:ok, result} = CategorizationResponse.validate(data)
      assert result.category == "Produce"
      assert result.confidence == 0.95
      assert result.confidence_level == "high"
    end

    test "validates with only required fields" do
      data = %{"category" => "Dairy", "confidence" => 0.7}
      assert {:ok, result} = CategorizationResponse.validate(data)
      assert result.category == "Dairy"
      assert is_nil(result.confidence_level)
    end

    test "rejects confidence above 1.0" do
      data = %{"category" => "Produce", "confidence" => 1.5}
      assert {:error, changeset} = CategorizationResponse.validate(data)
      assert errors_on(changeset, :confidence) != []
    end

    test "rejects negative confidence" do
      data = %{"category" => "Produce", "confidence" => -0.1}
      assert {:error, changeset} = CategorizationResponse.validate(data)
      assert errors_on(changeset, :confidence) != []
    end

    test "rejects missing category" do
      data = %{"confidence" => 0.5}
      assert {:error, changeset} = CategorizationResponse.validate(data)
      assert "can't be blank" in errors_on(changeset, :category)
    end

    test "rejects invalid confidence_level" do
      data = %{"category" => "Produce", "confidence" => 0.5, "confidence_level" => "very_high"}
      assert {:error, changeset} = CategorizationResponse.validate(data)
      assert "is invalid" in errors_on(changeset, :confidence_level)
    end

    property "accepts any valid confidence value in [0.0, 1.0]" do
      check all(
              category <- category_gen(),
              confidence <- confidence_gen(),
              level <- confidence_level_gen()
            ) do
        data = %{
          "category" => category,
          "confidence" => confidence,
          "confidence_level" => level
        }

        assert {:ok, result} = CategorizationResponse.validate(data)
        assert result.confidence >= 0.0 and result.confidence <= 1.0
      end
    end

    property "rejects confidence outside [0.0, 1.0]" do
      check all(
              bad_conf <-
                StreamData.filter(StreamData.float(min: -100.0, max: 100.0), fn v ->
                  v < 0.0 or v > 1.0
                end)
            ) do
        data = %{"category" => "Produce", "confidence" => bad_conf}
        assert {:error, _} = CategorizationResponse.validate(data)
      end
    end
  end

  # ── BatchPrediction ─────────────────────────────────────────────────

  describe "BatchPrediction" do
    test "validates a single prediction" do
      data = %{
        "id" => "item-1",
        "name" => "Bananas",
        "predicted_category" => "Produce",
        "confidence" => 0.92,
        "confidence_level" => "high"
      }

      assert {:ok, result} = BatchPrediction.validate(data)
      assert result.id == "item-1"
      assert result.predicted_category == "Produce"
    end

    test "rejects missing predicted_category" do
      data = %{"id" => "item-1", "confidence" => 0.5}
      assert {:error, changeset} = BatchPrediction.validate(data)
      assert "can't be blank" in errors_on(changeset, :predicted_category)
    end
  end

  # ── BatchCategorizationResponse ─────────────────────────────────────

  describe "BatchCategorizationResponse" do
    test "validates a batch response with multiple predictions" do
      data = %{
        "predictions" => [
          %{
            "id" => "1",
            "name" => "Milk",
            "predicted_category" => "Dairy",
            "confidence" => 0.9,
            "confidence_level" => "high"
          },
          %{
            "id" => "2",
            "name" => "Bread",
            "predicted_category" => "Bakery",
            "confidence" => 0.8,
            "confidence_level" => "high"
          }
        ],
        "processing_time_ms" => 25.0
      }

      assert {:ok, result} = BatchCategorizationResponse.validate(data)
      assert length(result.predictions) == 2
      assert result.processing_time_ms == 25.0
    end

    test "validates an empty batch" do
      data = %{"predictions" => [], "processing_time_ms" => 1.0}
      assert {:ok, result} = BatchCategorizationResponse.validate(data)
      assert result.predictions == []
    end

    test "rejects when a prediction is invalid" do
      data = %{
        "predictions" => [
          %{
            "id" => "1",
            "predicted_category" => "Dairy",
            "confidence" => 2.0,
            "confidence_level" => "high"
          }
        ],
        "processing_time_ms" => 5.0
      }

      assert {:error, _} = BatchCategorizationResponse.validate(data)
    end

    test "rejects missing predictions key" do
      assert {:error, :invalid_batch_categorization_response} =
               BatchCategorizationResponse.validate(%{"processing_time_ms" => 5.0})
    end

    property "batch with N valid predictions validates correctly" do
      check all(
              n <- StreamData.integer(0..10),
              predictions <-
                StreamData.list_of(
                  StreamData.fixed_map(%{
                    "id" => uuid_gen(),
                    "name" => non_empty_string(),
                    "predicted_category" => category_gen(),
                    "confidence" => confidence_gen(),
                    "confidence_level" => confidence_level_gen()
                  }),
                  length: n
                ),
              time <- positive_float()
            ) do
        data = %{"predictions" => predictions, "processing_time_ms" => time}
        assert {:ok, result} = BatchCategorizationResponse.validate(data)
        assert length(result.predictions) == n
      end
    end
  end

  # ── ReceiptLineItem ─────────────────────────────────────────────────

  describe "ReceiptLineItem" do
    test "validates a complete line item" do
      data = %{
        "raw_text" => "BANANAS 1.29",
        "parsed_name" => "Bananas",
        "quantity" => 1.0,
        "unit" => "bunch",
        "confidence" => 0.85
      }

      assert {:ok, result} = ReceiptLineItem.validate(data)
      assert result.parsed_name == "Bananas"
    end

    test "validates with only required fields" do
      data = %{"raw_text" => "MILK 3.99", "confidence" => 0.7}
      assert {:ok, result} = ReceiptLineItem.validate(data)
      assert is_nil(result.parsed_name)
    end

    test "rejects missing raw_text" do
      data = %{"confidence" => 0.5, "parsed_name" => "Test"}
      assert {:error, changeset} = ReceiptLineItem.validate(data)
      assert "can't be blank" in errors_on(changeset, :raw_text)
    end
  end

  # ── ReceiptExtractionResponse ───────────────────────────────────────

  describe "ReceiptExtractionResponse" do
    test "validates a complete receipt extraction" do
      data = %{
        "extraction" => %{
          "merchant" => %{"name" => "Trader Joe's", "confidence" => 0.9},
          "date" => %{"value" => "2026-01-15", "confidence" => 0.8},
          "total" => %{"amount" => "42.50", "currency" => "USD", "confidence" => 0.95},
          "line_items" => [
            %{
              "raw_text" => "BANANAS 1.29",
              "parsed_name" => "Bananas",
              "quantity" => 1.0,
              "confidence" => 0.9
            },
            %{
              "raw_text" => "MILK 3.99",
              "parsed_name" => "Milk",
              "quantity" => 1.0,
              "confidence" => 0.85
            }
          ],
          "overall_confidence" => 0.88,
          "raw_ocr_text" => "TRADER JOE'S\nBANANAS 1.29\nMILK 3.99\nTOTAL 42.50"
        }
      }

      assert {:ok, result} = ReceiptExtractionResponse.validate(data)
      assert result.merchant == "Trader Joe's"
      assert result.date == "2026-01-15"
      assert length(result.line_items) == 2
      assert result.overall_confidence == 0.88
    end

    test "validates receipt with empty line items" do
      data = %{
        "extraction" => %{
          "merchant" => %{"name" => nil, "confidence" => 0.0},
          "date" => %{"value" => nil, "confidence" => 0.0},
          "total" => %{"amount" => nil, "currency" => "USD", "confidence" => 0.0},
          "line_items" => [],
          "overall_confidence" => 0.1,
          "raw_ocr_text" => ""
        }
      }

      assert {:ok, result} = ReceiptExtractionResponse.validate(data)
      assert result.line_items == []
    end

    test "rejects missing extraction key" do
      assert {:error, :missing_extraction} =
               ReceiptExtractionResponse.validate(%{"status" => "success"})
    end

    test "rejects when line item is invalid" do
      data = %{
        "extraction" => %{
          "merchant" => %{"name" => "Store"},
          "date" => %{"value" => nil},
          "total" => %{"amount" => nil},
          "line_items" => [%{"confidence" => 0.5}],
          "overall_confidence" => 0.5
        }
      }

      assert {:error, _} = ReceiptExtractionResponse.validate(data)
    end

    property "receipts with N valid line items validate correctly" do
      check all(
              n <- StreamData.integer(0..8),
              items <-
                StreamData.list_of(
                  StreamData.fixed_map(%{
                    "raw_text" => non_empty_string(),
                    "parsed_name" => non_empty_string(),
                    "quantity" => positive_float(),
                    "confidence" => confidence_gen()
                  }),
                  length: n
                )
            ) do
        data = %{
          "extraction" => %{
            "merchant" => %{"name" => "Store", "confidence" => 0.9},
            "date" => %{"value" => "2026-01-01", "confidence" => 0.8},
            "total" => %{"amount" => "10.00", "currency" => "USD", "confidence" => 0.9},
            "line_items" => items,
            "overall_confidence" => 0.85,
            "raw_ocr_text" => "text"
          }
        }

        assert {:ok, result} = ReceiptExtractionResponse.validate(data)
        assert length(result.line_items) == n
      end
    end
  end

  # ── EmbeddingEntry ──────────────────────────────────────────────────

  describe "EmbeddingEntry" do
    test "validates a valid embedding entry" do
      data = %{"id" => "text-1", "vector" => [0.1, 0.2, 0.3]}
      assert {:ok, result} = EmbeddingEntry.validate(data)
      assert result.id == "text-1"
      assert length(result.vector) == 3
    end

    test "rejects missing vector" do
      data = %{"id" => "text-1"}
      assert {:error, changeset} = EmbeddingEntry.validate(data)
      assert "can't be blank" in errors_on(changeset, :vector)
    end
  end

  # ── EmbeddingResponse ───────────────────────────────────────────────

  describe "EmbeddingResponse" do
    test "validates a complete embedding response" do
      data = %{
        "model" => "all-MiniLM-L6-v2",
        "dimension" => 384,
        "embeddings" => [
          %{"id" => "1", "vector" => List.duplicate(0.1, 384)}
        ]
      }

      assert {:ok, result} = EmbeddingResponse.validate(data)
      assert result.model == "all-MiniLM-L6-v2"
      assert result.dimension == 384
      assert length(result.embeddings) == 1
    end

    test "validates with empty embeddings list" do
      data = %{"model" => "test", "dimension" => 384, "embeddings" => []}
      assert {:ok, result} = EmbeddingResponse.validate(data)
      assert result.embeddings == []
    end

    test "rejects missing model field" do
      data = %{"dimension" => 384, "embeddings" => []}
      assert {:error, {:missing_field, "model"}} = EmbeddingResponse.validate(data)
    end

    test "rejects missing dimension field" do
      data = %{"model" => "test", "embeddings" => []}
      assert {:error, {:missing_field, "dimension"}} = EmbeddingResponse.validate(data)
    end

    property "embedding responses with valid vectors pass validation" do
      check all(
              dim <- StreamData.integer(1..384),
              n <- StreamData.integer(1..5),
              entries <-
                StreamData.list_of(
                  StreamData.fixed_map(%{
                    "id" => uuid_gen(),
                    "vector" =>
                      StreamData.list_of(StreamData.float(min: -1.0, max: 1.0), length: dim)
                  }),
                  length: n
                )
            ) do
        data = %{"model" => "test-model", "dimension" => dim, "embeddings" => entries}
        assert {:ok, result} = EmbeddingResponse.validate(data)
        assert length(result.embeddings) == n
      end
    end
  end

  # ── HealthCheckResponse ─────────────────────────────────────────────

  describe "HealthCheckResponse" do
    test "validates a healthy response" do
      data = %{
        "status" => "ok",
        "checks" => %{
          "database" => %{"status" => "ok"},
          "classifier" => %{"status" => "ok", "model" => "distilbart"},
          "embedding_model" => %{"status" => "available"}
        },
        "version" => "1.0.0"
      }

      assert {:ok, result} = HealthCheckResponse.validate(data)
      assert result.status == "ok"
    end

    test "validates a degraded response" do
      data = %{"status" => "degraded", "checks" => %{"database" => %{"status" => "error"}}}
      assert {:ok, result} = HealthCheckResponse.validate(data)
      assert result.status == "degraded"
    end

    test "rejects invalid status" do
      data = %{"status" => "broken"}
      assert {:error, changeset} = HealthCheckResponse.validate(data)
      assert "is invalid" in errors_on(changeset, :status)
    end

    test "rejects missing status" do
      data = %{"checks" => %{}}
      assert {:error, changeset} = HealthCheckResponse.validate(data)
      assert "can't be blank" in errors_on(changeset, :status)
    end

    property "accepts all valid health statuses" do
      check all(status <- StreamData.member_of(["ok", "degraded", "error"])) do
        data = %{"status" => status, "checks" => %{}, "version" => "1.0.0"}
        assert {:ok, result} = HealthCheckResponse.validate(data)
        assert result.status == status
      end
    end
  end

  # ── MealPlanEntry ───────────────────────────────────────────────────

  describe "MealPlanEntry" do
    test "validates a complete meal plan entry" do
      data = %{
        "date" => "2026-02-10",
        "day_index" => 0,
        "meal_type" => "dinner",
        "recipe_id" => "recipe-123",
        "recipe_name" => "Pasta Primavera"
      }

      assert {:ok, result} = MealPlanEntry.validate(data)
      assert result.recipe_name == "Pasta Primavera"
    end

    test "rejects missing recipe_id" do
      data = %{"date" => "2026-02-10", "recipe_name" => "Test"}
      assert {:error, changeset} = MealPlanEntry.validate(data)
      assert "can't be blank" in errors_on(changeset, :recipe_id)
    end
  end

  # ── MealOptimizationResponse ────────────────────────────────────────

  describe "MealOptimizationResponse" do
    test "validates an optimal plan response" do
      data = %{
        "status" => "optimal",
        "solve_time_ms" => 150,
        "meal_plan" => [
          %{
            "date" => "2026-02-10",
            "day_index" => 0,
            "meal_type" => "dinner",
            "recipe_id" => "r1",
            "recipe_name" => "Pasta"
          }
        ],
        "shopping_list" => [%{"ingredient_id" => "i1", "name" => "Tomatoes", "quantity" => 2}],
        "metrics" => %{"expiring_ingredients_used" => 3, "variety_score" => 0.8},
        "explanation" => ["Used 3 expiring ingredients"]
      }

      assert {:ok, result} = MealOptimizationResponse.validate(data)
      assert result.status == "optimal"
      assert length(result.meal_plan) == 1
    end

    test "validates a no_solution response" do
      data = %{"status" => "no_solution", "explanation" => ["Constraints unsatisfiable"]}
      assert {:ok, result} = MealOptimizationResponse.validate(data)
      assert result.status == "no_solution"
      assert result.meal_plan == []
    end

    test "rejects missing status" do
      assert {:error, :missing_status} = MealOptimizationResponse.validate(%{})
    end

    test "rejects unknown status" do
      assert {:error, {:invalid_status, "pending"}} =
               MealOptimizationResponse.validate(%{"status" => "pending"})
    end

    test "rejects when meal plan entry is invalid" do
      data = %{
        "status" => "optimal",
        "meal_plan" => [%{"date" => "2026-02-10"}]
      }

      assert {:error, _} = MealOptimizationResponse.validate(data)
    end

    property "optimal plans with valid entries pass validation" do
      check all(
              n <- StreamData.integer(1..7),
              entries <-
                StreamData.list_of(
                  StreamData.fixed_map(%{
                    "date" => StreamData.constant("2026-02-10"),
                    "day_index" => StreamData.integer(0..6),
                    "meal_type" => StreamData.member_of(["breakfast", "lunch", "dinner"]),
                    "recipe_id" => uuid_gen(),
                    "recipe_name" => non_empty_string()
                  }),
                  length: n
                )
            ) do
        data = %{
          "status" => "optimal",
          "meal_plan" => entries,
          "shopping_list" => [],
          "metrics" => %{},
          "explanation" => []
        }

        assert {:ok, result} = MealOptimizationResponse.validate(data)
        assert length(result.meal_plan) == n
      end
    end
  end

  # ── QuickSuggestionEntry ────────────────────────────────────────────

  describe "QuickSuggestionEntry" do
    test "validates a suggestion entry" do
      data = %{
        "recipe_id" => "r1",
        "recipe_name" => "Quick Stir Fry",
        "score" => 0.85,
        "reason" => "Uses 3 expiring ingredients"
      }

      assert {:ok, result} = QuickSuggestionEntry.validate(data)
      assert result.recipe_name == "Quick Stir Fry"
    end

    test "rejects negative score" do
      data = %{"recipe_id" => "r1", "recipe_name" => "Test", "score" => -0.5}
      assert {:error, changeset} = QuickSuggestionEntry.validate(data)
      assert errors_on(changeset, :score) != []
    end
  end

  # ── QuickSuggestionResponse ─────────────────────────────────────────

  describe "QuickSuggestionResponse" do
    test "validates a response with suggestions" do
      data = %{
        "suggestions" => [
          %{"recipe_id" => "r1", "recipe_name" => "Salad", "score" => 0.9, "reason" => "Fresh"},
          %{"recipe_id" => "r2", "recipe_name" => "Soup", "score" => 0.7, "reason" => "Warm"}
        ]
      }

      assert {:ok, result} = QuickSuggestionResponse.validate(data)
      assert length(result.suggestions) == 2
    end

    test "validates empty suggestions" do
      data = %{"suggestions" => []}
      assert {:ok, result} = QuickSuggestionResponse.validate(data)
      assert result.suggestions == []
    end

    test "rejects missing suggestions key" do
      assert {:error, :missing_suggestions} = QuickSuggestionResponse.validate(%{})
    end

    test "rejects invalid suggestion entry" do
      data = %{"suggestions" => [%{"recipe_id" => "r1"}]}
      assert {:error, _} = QuickSuggestionResponse.validate(data)
    end

    property "valid suggestions always pass validation" do
      check all(
              n <- StreamData.integer(0..10),
              suggestions <-
                StreamData.list_of(
                  StreamData.fixed_map(%{
                    "recipe_id" => uuid_gen(),
                    "recipe_name" => non_empty_string(),
                    "score" => positive_float(),
                    "reason" => non_empty_string()
                  }),
                  length: n
                )
            ) do
        data = %{"suggestions" => suggestions}
        assert {:ok, result} = QuickSuggestionResponse.validate(data)
        assert length(result.suggestions) == n
      end
    end
  end

  # ── Cross-cutting property tests ────────────────────────────────────

  describe "cross-cutting: all contracts reject non-map input" do
    @contracts [
      BaseResponse,
      CategorizationResponse,
      BatchPrediction,
      ReceiptLineItem,
      EmbeddingEntry,
      HealthCheckResponse,
      MealPlanEntry,
      QuickSuggestionEntry
    ]

    for contract <- @contracts do
      test "#{inspect(contract)} rejects nil" do
        assert {:error, _} = unquote(contract).validate(nil)
      end

      test "#{inspect(contract)} rejects string" do
        assert {:error, _} = unquote(contract).validate("hello")
      end

      test "#{inspect(contract)} rejects integer" do
        assert {:error, _} = unquote(contract).validate(42)
      end

      test "#{inspect(contract)} rejects list" do
        assert {:error, _} = unquote(contract).validate([1, 2, 3])
      end
    end
  end

  # ── Helper ──────────────────────────────────────────────────────────

  defp errors_on(changeset, field) do
    changeset.errors
    |> Keyword.get_values(field)
    |> Enum.map(fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
