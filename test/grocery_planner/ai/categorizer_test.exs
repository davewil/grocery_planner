defmodule GroceryPlanner.AI.CategorizerTest do
  use ExUnit.Case, async: true

  alias GroceryPlanner.AI.Categorizer
  alias GroceryPlanner.AiClient

  describe "confidence_level/1" do
    test "returns :high for confidence >= 0.80" do
      assert Categorizer.confidence_level(0.80) == :high
      assert Categorizer.confidence_level(0.95) == :high
      assert Categorizer.confidence_level(1.0) == :high
    end

    test "returns :medium for confidence >= 0.50 and < 0.80" do
      assert Categorizer.confidence_level(0.50) == :medium
      assert Categorizer.confidence_level(0.65) == :medium
      assert Categorizer.confidence_level(0.79) == :medium
    end

    test "returns :low for confidence < 0.50" do
      assert Categorizer.confidence_level(0.0) == :low
      assert Categorizer.confidence_level(0.30) == :low
      assert Categorizer.confidence_level(0.49) == :low
    end
  end

  describe "enabled?/0" do
    test "returns false when feature flag is disabled" do
      # Test config has ai_categorization: false
      refute Categorizer.enabled?()
    end

    test "returns true when feature flag is enabled" do
      original = Application.get_env(:grocery_planner, :features)

      Application.put_env(:grocery_planner, :features,
        ai_categorization: true,
        semantic_search: false
      )

      assert Categorizer.enabled?()

      Application.put_env(:grocery_planner, :features, original || [])
    end
  end

  describe "predict/2" do
    test "returns {:error, :disabled} when feature flag is off" do
      assert {:error, :disabled} = Categorizer.predict("Milk")
    end

    test "returns prediction when feature flag is on" do
      original = Application.get_env(:grocery_planner, :features)

      Application.put_env(:grocery_planner, :features,
        ai_categorization: true,
        semantic_search: false
      )

      Req.Test.stub(AiClient, fn conn ->
        Req.Test.json(conn, %{
          "request_id" => "req_test",
          "status" => "success",
          "payload" => %{
            "category" => "Dairy",
            "confidence" => 0.94,
            "confidence_level" => "high"
          }
        })
      end)

      assert {:ok, prediction} =
               Categorizer.predict("Milk",
                 candidate_labels: ["Dairy", "Produce"],
                 tenant_id: "test_tenant",
                 user_id: "test_user",
                 plug: {Req.Test, AiClient}
               )

      assert prediction.category == "Dairy"
      assert prediction.confidence == 0.94
      assert prediction.confidence_level == :high

      Application.put_env(:grocery_planner, :features, original || [])
    end

    test "returns error on AI service failure" do
      original = Application.get_env(:grocery_planner, :features)

      Application.put_env(:grocery_planner, :features,
        ai_categorization: true,
        semantic_search: false
      )

      Req.Test.stub(AiClient, fn conn ->
        Plug.Conn.send_resp(conn, 500, "Internal Server Error")
      end)

      assert {:error, _} =
               Categorizer.predict("Unknown",
                 tenant_id: "test_tenant",
                 user_id: "test_user",
                 plug: {Req.Test, AiClient}
               )

      Application.put_env(:grocery_planner, :features, original || [])
    end
  end

  describe "predict_batch/2" do
    test "returns {:error, :disabled} when feature flag is off" do
      assert {:error, :disabled} = Categorizer.predict_batch(["Milk", "Bread"])
    end

    test "returns {:error, :batch_too_large} for more than 50 items" do
      original = Application.get_env(:grocery_planner, :features)

      Application.put_env(:grocery_planner, :features,
        ai_categorization: true,
        semantic_search: false
      )

      items = for i <- 1..51, do: "Item #{i}"
      assert {:error, :batch_too_large} = Categorizer.predict_batch(items)

      Application.put_env(:grocery_planner, :features, original || [])
    end
  end

  describe "default_candidate_labels/0" do
    test "returns a list of category strings" do
      labels = Categorizer.default_candidate_labels()
      assert is_list(labels)
      assert "Dairy" in labels
      assert "Produce" in labels
      assert length(labels) == 10
    end
  end
end
