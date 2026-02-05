defmodule GroceryPlanner.AiClientHealthTest do
  use ExUnit.Case, async: false

  alias GroceryPlanner.AiClient

  describe "health_check/1" do
    test "returns {:ok, body} when service responds 200 with healthy status" do
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        Req.Test.json(conn, %{
          "status" => "ok",
          "checks" => %{
            "database" => %{"status" => "ok"},
            "classifier" => %{"status" => "not_loaded"}
          },
          "version" => "1.0.0"
        })
      end)

      assert {:ok, body} = AiClient.health_check()
      assert body["status"] == "ok"
      assert body["checks"]["database"]["status"] == "ok"
      assert body["version"] == "1.0.0"
    end

    test "returns {:ok, body} when service reports degraded status" do
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        Req.Test.json(conn, %{
          "status" => "degraded",
          "checks" => %{
            "database" => %{"status" => "error", "error" => "connection refused"}
          },
          "version" => "1.0.0"
        })
      end)

      assert {:ok, body} = AiClient.health_check()
      assert body["status"] == "degraded"
    end

    test "returns {:error, {:unhealthy, status, body}} on non-200 response" do
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(503, Jason.encode!(%{"error" => "service unavailable"}))
      end)

      assert {:error, {:unhealthy, 503, body}} = AiClient.health_check()
      assert body["error"] == "service unavailable"
    end

    test "returns {:error, {:connection_failed, reason}} on connection error" do
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, {:connection_failed, %Req.TransportError{reason: :econnrefused}}} =
               AiClient.health_check()
    end

    test "passes through full checks map with all dependency statuses" do
      checks = %{
        "database" => %{"status" => "ok"},
        "classifier" => %{"status" => "ok", "model" => "distilbart"},
        "embedding_model" => %{"status" => "available"},
        "tesseract" => %{"status" => "not_installed"}
      }

      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        Req.Test.json(conn, %{"status" => "ok", "checks" => checks, "version" => "1.0.0"})
      end)

      assert {:ok, body} = AiClient.health_check()
      assert body["checks"] == checks
    end

    test "calls /health/ready endpoint" do
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        assert conn.request_path == "/health/ready"
        assert conn.method == "GET"
        Req.Test.json(conn, %{"status" => "ok", "checks" => %{}, "version" => "1.0.0"})
      end)

      assert {:ok, _} = AiClient.health_check()
    end
  end
end
