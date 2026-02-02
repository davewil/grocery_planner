defmodule GroceryPlanner.AiClientTest do
  use ExUnit.Case, async: true
  alias GroceryPlanner.AiClient

  @context %{
    tenant_id: "tenant_123",
    user_id: "user_456"
  }

  describe "categorize_item/4" do
    test "successfully categorizes an item" do
      Req.Test.stub(AiClient, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v1/categorize"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["feature"] == "categorization"
        assert params["tenant_id"] == @context.tenant_id
        assert params["payload"]["item_name"] == "Milk"
        assert params["payload"]["candidate_labels"] == ["Dairy", "Produce"]

        Req.Test.json(conn, %{
          "request_id" => "req_1",
          "status" => "success",
          "payload" => %{
            "category" => "Dairy",
            "confidence" => 0.99
          }
        })
      end)

      assert {:ok, response} =
               AiClient.categorize_item("Milk", ["Dairy", "Produce"], @context,
                 plug: {Req.Test, AiClient}
               )

      assert response["status"] == "success"
      assert response["payload"]["category"] == "Dairy"
    end
  end

  describe "extract_receipt/3" do
    test "successfully extracts items from receipt" do
      Req.Test.stub(AiClient, fn conn ->
        assert conn.request_path == "/api/v1/extract-receipt"

        Req.Test.json(conn, %{
          "request_id" => "req_2",
          "status" => "success",
          "payload" => %{
            "items" => [
              %{"name" => "Bananas", "quantity" => 1.0}
            ],
            "total" => 5.00
          }
        })
      end)

      assert {:ok, response} =
               AiClient.extract_receipt("base64_img", @context, plug: {Req.Test, AiClient})

      assert response["payload"]["total"] == 5.00
    end
  end

  describe "submit_job/4" do
    test "successfully submits a job" do
      Req.Test.stub(AiClient, fn conn ->
        assert conn.request_path == "/api/v1/jobs"

        Req.Test.json(conn, %{
          "job_id" => "job_123",
          "status" => "queued",
          "feature" => "bulk_import"
        })
      end)

      assert {:ok, response} =
               AiClient.submit_job("bulk_import", %{}, @context, plug: {Req.Test, AiClient})

      assert response["job_id"] == "job_123"
      assert response["status"] == "queued"
    end
  end

  describe "get_job/3" do
    test "successfully retrieves job status" do
      Req.Test.stub(AiClient, fn conn ->
        assert conn.request_path == "/api/v1/jobs/job_123"
        assert {"x-tenant-id", @context.tenant_id} in conn.req_headers

        Req.Test.json(conn, %{
          "job_id" => "job_123",
          "status" => "succeeded",
          "feature" => "bulk_import"
        })
      end)

      assert {:ok, response} = AiClient.get_job("job_123", @context, plug: {Req.Test, AiClient})
      assert response["status"] == "succeeded"
    end
  end

  describe "categorize_batch/4" do
    test "successfully categorizes a batch of items" do
      Req.Test.stub(AiClient, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v1/categorize-batch"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["feature"] == "categorization_batch"
        assert params["tenant_id"] == @context.tenant_id
        assert length(params["payload"]["items"]) == 2
        assert params["payload"]["candidate_labels"] == ["Dairy", "Produce"]

        Req.Test.json(conn, %{
          "request_id" => "req_batch",
          "status" => "success",
          "payload" => %{
            "predictions" => [
              %{
                "id" => "1",
                "name" => "Milk",
                "predicted_category" => "Dairy",
                "confidence" => 0.94,
                "confidence_level" => "high"
              },
              %{
                "id" => "2",
                "name" => "Bananas",
                "predicted_category" => "Produce",
                "confidence" => 0.91,
                "confidence_level" => "high"
              }
            ],
            "processing_time_ms" => 150.5
          }
        })
      end)

      items = [
        %{id: "1", name: "Milk"},
        %{id: "2", name: "Bananas"}
      ]

      assert {:ok, response} =
               AiClient.categorize_batch(items, ["Dairy", "Produce"], @context,
                 plug: {Req.Test, AiClient}
               )

      assert response["status"] == "success"
      assert length(response["payload"]["predictions"]) == 2
    end
  end
end
