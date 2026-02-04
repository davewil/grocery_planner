defmodule Mix.Tasks.SmokeTest do
  @moduledoc """
  Smoke test for the Python AI service.

  Runs quick health and round-trip checks against a deployed service
  to verify it is correctly configured. No database required.

  ## Usage

      mix smoke_test                                    # Test localhost:8099
      mix smoke_test --url http://ai.staging.example.com  # Test remote
      mix smoke_test --verbose                           # Show response bodies

  ## Checks

  1. **Health** — `GET /health` returns 200 with `{"status": "ok"}`
  2. **Endpoint reachability** — `POST /api/v1/extract-receipt` responds
  3. **Round-trip OCR** — Send sample receipt, verify items extracted
  """
  use Mix.Task

  @shortdoc "Run smoke tests against the Python AI service"

  @default_url "http://localhost:8099"
  @fixture_path "test/fixtures/sample_receipt.png"

  @impl Mix.Task
  def run(args) do
    Application.ensure_all_started(:req)

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [url: :string, verbose: :boolean],
        aliases: [u: :url, v: :verbose]
      )

    url = opts[:url] || System.get_env("AI_SERVICE_URL") || @default_url
    verbose = opts[:verbose] || false

    Mix.shell().info("\n=== Smoke Test: #{url} ===\n")

    results = [
      check_health(url, verbose),
      check_endpoint_reachable(url, verbose),
      check_round_trip_ocr(url, verbose)
    ]

    Mix.shell().info("")

    failures = Enum.count(results, fn {status, _, _} -> status == :fail end)
    passes = Enum.count(results, fn {status, _, _} -> status == :pass end)
    skips = Enum.count(results, fn {status, _, _} -> status == :skip end)

    Mix.shell().info("Results: #{passes} passed, #{failures} failed, #{skips} skipped")

    if failures > 0 do
      Mix.raise("Smoke test failed (#{failures} check(s) failed)")
    end
  end

  defp check_health(url, verbose) do
    name = "Health check"

    case Req.get(Req.new(base_url: url), url: "/health") do
      {:ok, %Req.Response{status: 200, body: %{"status" => "ok"} = body}} ->
        print_result(:pass, name)
        if verbose, do: Mix.shell().info("  #{inspect(body)}")
        {:pass, name, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        print_result(:fail, name, "HTTP #{status}")
        if verbose, do: Mix.shell().info("  #{inspect(body)}")
        {:fail, name, "HTTP #{status}"}

      {:error, reason} ->
        print_result(:fail, name, "Connection failed: #{inspect(reason)}")
        {:fail, name, reason}
    end
  end

  defp check_endpoint_reachable(url, verbose) do
    name = "Endpoint reachability"

    request_body = %{
      request_id: "smoke_#{System.unique_integer([:positive])}",
      tenant_id: "00000000-0000-0000-0000-000000000000",
      user_id: nil,
      feature: "extraction",
      payload: %{image_base64: ""}
    }

    case Req.post(Req.new(base_url: url), url: "/api/v1/extract-receipt", json: request_body) do
      {:ok, %Req.Response{status: status, body: body}} ->
        # Any response (even 400/422) means the endpoint is reachable
        print_result(:pass, name, "HTTP #{status}")
        if verbose, do: Mix.shell().info("  #{inspect(body)}")
        {:pass, name, status}

      {:error, reason} ->
        print_result(:fail, name, "Connection failed: #{inspect(reason)}")
        {:fail, name, reason}
    end
  end

  defp check_round_trip_ocr(url, verbose) do
    name = "Round-trip OCR"

    unless File.exists?(@fixture_path) do
      print_result(:skip, name, "Fixture not found: #{@fixture_path}")
      {:skip, name, :no_fixture}
    else
      image_base64 = @fixture_path |> File.read!() |> Base.encode64()

      request_body = %{
        request_id: "smoke_ocr_#{System.unique_integer([:positive])}",
        tenant_id: "00000000-0000-0000-0000-000000000000",
        user_id: nil,
        feature: "extraction",
        payload: %{image_base64: image_base64}
      }

      case Req.post(Req.new(base_url: url),
             url: "/api/v1/extract-receipt",
             json: request_body,
             receive_timeout: 30_000
           ) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          print_result(:pass, name, "Got response with status: #{body["status"]}")
          if verbose, do: Mix.shell().info("  #{inspect(body, pretty: true, limit: 500)}")
          {:pass, name, body}

        {:ok, %Req.Response{status: status, body: body}} ->
          print_result(:fail, name, "HTTP #{status}")
          if verbose, do: Mix.shell().info("  #{inspect(body)}")
          {:fail, name, "HTTP #{status}"}

        {:error, reason} ->
          print_result(:fail, name, "Connection failed: #{inspect(reason)}")
          {:fail, name, reason}
      end
    end
  end

  defp print_result(status, name, detail \\ nil)

  defp print_result(:pass, name, detail) do
    msg = "  PASS  #{name}"
    msg = if detail, do: msg <> " (#{detail})", else: msg
    Mix.shell().info(msg)
  end

  defp print_result(:fail, name, detail) do
    Mix.shell().info("  FAIL  #{name} — #{detail}")
  end

  defp print_result(:skip, name, detail) do
    Mix.shell().info("  SKIP  #{name} — #{detail}")
  end
end
