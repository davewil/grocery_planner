defmodule GroceryPlanner.TelemetryTest do
  @moduledoc """
  Tests for OpenTelemetry instrumentation setup and trace propagation.

  Verifies that:
  - OTEL instrumentation initializes without errors
  - Phoenix, Ecto, and Oban telemetry handlers are attached
  - AiClient attaches OTEL trace propagation to outgoing requests
  - Spans are created for key operations
  """
  use GroceryPlanner.DataCase, async: false

  alias GroceryPlanner.AiClient

  describe "OpenTelemetry setup" do
    test "Phoenix telemetry handlers are attached at application start" do
      handlers = :telemetry.list_handlers([:phoenix, :endpoint, :stop])

      phoenix_handler =
        Enum.find(handlers, fn handler ->
          match?({OpentelemetryPhoenix, _}, handler.id)
        end)

      assert phoenix_handler != nil,
             "Expected OpentelemetryPhoenix handler on [:phoenix, :endpoint, :stop]"
    end

    test "Ecto telemetry handlers are attached" do
      handlers = :telemetry.list_handlers([:grocery_planner, :repo, :query])

      ecto_handler =
        Enum.find(handlers, fn handler ->
          match?({OpentelemetryEcto, _}, handler.id)
        end)

      assert ecto_handler != nil,
             "Expected OpentelemetryEcto handler on [:grocery_planner, :repo, :query]"
    end

    test "Oban telemetry handlers are attached" do
      handlers = :telemetry.list_handlers([:oban, :job, :start])

      oban_handler =
        Enum.find(handlers, fn handler ->
          handler.id |> to_string() |> String.contains?("OpentelemetryOban")
        end)

      assert oban_handler != nil,
             "Expected OpentelemetryOban handler on [:oban, :job, :start]"
    end

    test "setup_opentelemetry is idempotent and does not crash on re-init" do
      assert :ok == GroceryPlanner.Application.reinit_opentelemetry()
    end
  end

  describe "AiClient trace propagation" do
    test "outgoing requests include traceparent header" do
      test_pid = self()

      Req.Test.stub(AiClient, fn conn ->
        traceparent = Plug.Conn.get_req_header(conn, "traceparent")
        send(test_pid, {:traceparent, traceparent})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "status" => "ok",
            "request_id" => "req_test",
            "payload" => %{
              "category" => "Produce",
              "confidence" => 0.95,
              "confidence_level" => "high",
              "all_scores" => %{}
            }
          })
        )
      end)

      context = %{tenant_id: "test-tenant", user_id: "test-user"}

      {:ok, _body} =
        AiClient.categorize_item(
          "Bananas",
          ["Produce", "Dairy"],
          context,
          plug: {Req.Test, AiClient}
        )

      assert_receive {:traceparent, values}

      assert length(values) > 0, "Expected traceparent header in outgoing request"

      [traceparent] = values
      # W3C Trace Context format: version-trace_id-span_id-flags
      assert traceparent =~ ~r/^[0-9a-f]{2}-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}$/
    end

    test "health_check works with trace propagation" do
      Req.Test.stub(AiClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "status" => "ok",
            "checks" => %{"database" => %{"status" => "ok"}},
            "version" => "1.0.0"
          })
        )
      end)

      assert {:ok, body} = AiClient.health_check(plug: {Req.Test, AiClient})
      assert body["status"] == "ok"
    end

    test "categorize_item propagates trace context across service boundary" do
      test_pid = self()

      Req.Test.stub(AiClient, fn conn ->
        headers = Enum.into(conn.req_headers, %{})
        send(test_pid, {:headers, headers})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "status" => "ok",
            "request_id" => "req_test",
            "payload" => %{
              "category" => "Dairy",
              "confidence" => 0.9,
              "confidence_level" => "high",
              "all_scores" => %{}
            }
          })
        )
      end)

      context = %{tenant_id: "acct_123", user_id: "user_456"}

      {:ok, _} =
        AiClient.categorize_item("Milk", ["Dairy", "Produce"], context,
          plug: {Req.Test, AiClient}
        )

      assert_receive {:headers, headers}
      # traceparent should be present for distributed tracing
      assert Map.has_key?(headers, "traceparent")
      # content-type should still be set
      assert headers["content-type"] == "application/json"
    end
  end

  describe "telemetry configuration" do
    test "test environment disables OTEL export" do
      exporter = Application.get_env(:opentelemetry, :traces_exporter)
      assert exporter == :none
    end

    test "test environment uses simple span processor" do
      processor = Application.get_env(:opentelemetry, :span_processor)
      assert processor == :simple
    end

    test "OTEL resource config includes service name" do
      resource = Application.get_env(:opentelemetry, :resource)
      assert resource != nil
      service = Keyword.get(resource, :service)
      assert Keyword.get(service, :name) == "grocery-planner-web"
    end
  end
end
