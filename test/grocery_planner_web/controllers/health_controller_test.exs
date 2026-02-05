defmodule GroceryPlannerWeb.HealthControllerTest do
  use GroceryPlannerWeb.ConnCase, async: false

  describe "GET /health_check (liveness)" do
    test "returns 200 with ok status", %{conn: conn} do
      conn = get(conn, "/health_check")

      assert json_response(conn, 200) == %{"status" => "ok"}
    end

    test "does not require authentication", %{conn: conn} do
      # No auth headers or session needed
      conn = get(conn, "/health_check")

      assert conn.status == 200
    end
  end

  describe "GET /health_check/ready (readiness)" do
    test "returns JSON with status, checks, and version", %{conn: conn} do
      # Stub AI service health check to return healthy
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        Req.Test.json(conn, %{
          "status" => "ok",
          "checks" => %{"database" => %{"status" => "ok"}},
          "version" => "1.0.0"
        })
      end)

      conn = get(conn, "/health_check/ready")

      body = json_response(conn, 200)
      assert body["status"]
      assert body["checks"]
      assert body["version"]
    end

    test "reports database as healthy when connected", %{conn: conn} do
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        Req.Test.json(conn, %{"status" => "ok", "checks" => %{}, "version" => "1.0.0"})
      end)

      conn = get(conn, "/health_check/ready")

      body = json_response(conn, 200)
      assert body["checks"]["database"]["status"] == "ok"
    end

    test "reports oban as healthy when running", %{conn: conn} do
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        Req.Test.json(conn, %{"status" => "ok", "checks" => %{}, "version" => "1.0.0"})
      end)

      conn = get(conn, "/health_check/ready")

      body = json_response(conn, 200)
      # Oban runs in test mode so the process should exist
      assert body["checks"]["oban"]["status"] == "ok"
    end

    test "returns degraded when AI service is unavailable", %{conn: conn} do
      # Stub AI service to simulate connection failure
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        Plug.Conn.send_resp(conn, 503, "Service Unavailable")
      end)

      conn = get(conn, "/health_check/ready")

      body = json_response(conn, 200)
      # AI service failure should result in degraded, not error
      assert body["status"] == "degraded"
      assert body["checks"]["ai_service"]["status"] in ["error", "unavailable"]
    end

    test "returns ok when all services are healthy", %{conn: conn} do
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

      conn = get(conn, "/health_check/ready")

      body = json_response(conn, 200)
      assert body["status"] == "ok"
      assert body["checks"]["database"]["status"] == "ok"
      assert body["checks"]["oban"]["status"] == "ok"
    end

    test "does not require authentication", %{conn: conn} do
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        Req.Test.json(conn, %{"status" => "ok", "checks" => %{}, "version" => "1.0.0"})
      end)

      conn = get(conn, "/health_check/ready")

      assert conn.status == 200
    end

    test "includes application version in response", %{conn: conn} do
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        Req.Test.json(conn, %{"status" => "ok", "checks" => %{}, "version" => "1.0.0"})
      end)

      conn = get(conn, "/health_check/ready")

      body = json_response(conn, 200)
      assert is_binary(body["version"])
    end

    test "AI service check passes through details from upstream", %{conn: conn} do
      Req.Test.stub(GroceryPlanner.AiClient, fn conn ->
        Req.Test.json(conn, %{
          "status" => "ok",
          "checks" => %{
            "database" => %{"status" => "ok"},
            "classifier" => %{"status" => "ok", "model" => "test-model"}
          },
          "version" => "1.0.0"
        })
      end)

      conn = get(conn, "/health_check/ready")

      body = json_response(conn, 200)
      assert body["checks"]["ai_service"]["status"] == "ok"
      assert body["checks"]["ai_service"]["details"]
    end
  end
end
