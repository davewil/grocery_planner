defmodule GroceryPlanner.AiClientHealthTest do
  use ExUnit.Case, async: false

  describe "health_check/0" do
    test "returns {:ok, body} when AI service is healthy" do
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        Req.Test.json(conn, %{
          "status" => "ok",
          "checks" => %{
            "database" => %{"status" => "ok"},
            "classifier" => %{"status" => "not_loaded", "model" => nil},
            "embedding_model" => %{"status" => "available"},
            "tesseract" => %{"status" => "available"}
          },
          "version" => "1.0.0"
        })
      end)

      assert {:ok, body} = GroceryPlanner.AiClient.health_check()
      assert body["status"] == "ok"
      assert body["checks"]["database"]["status"] == "ok"
      assert body["version"] == "1.0.0"
    end

    test "returns {:ok, body} when AI service is degraded" do
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        Req.Test.json(conn, %{
          "status" => "degraded",
          "checks" => %{
            "database" => %{"status" => "error", "error" => "connection refused"}
          },
          "version" => "1.0.0"
        })
      end)

      assert {:ok, body} = GroceryPlanner.AiClient.health_check()
      assert body["status"] == "degraded"
    end

    test "returns {:error, _} when AI service returns non-200" do
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        Plug.Conn.send_resp(conn, 503, "Service Unavailable")
      end)

      assert {:error, _reason} = GroceryPlanner.AiClient.health_check()
    end

    test "returns {:error, _} when AI service is unreachable" do
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, _reason} = GroceryPlanner.AiClient.health_check()
    end

    test "health check includes all dependency statuses" do
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        Req.Test.json(conn, %{
          "status" => "ok",
          "checks" => %{
            "database" => %{"status" => "ok"},
            "classifier" => %{"status" => "ok", "model" => "distilbart"},
            "embedding_model" => %{"status" => "available"},
            "tesseract" => %{"status" => "not_installed"}
          },
          "version" => "1.0.0"
        })
      end)

      {:ok, body} = GroceryPlanner.AiClient.health_check()
      checks = body["checks"]

      assert Map.has_key?(checks, "database")
      assert Map.has_key?(checks, "classifier")
      assert Map.has_key?(checks, "embedding_model")
      assert Map.has_key?(checks, "tesseract")
    end
  end
end
