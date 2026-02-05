# INFRA-002: Observability & Developer Experience

**Status**: IN PROGRESS (Phase 1 + Phase 4 + Phase 7 Complete)
**Priority**: High (blocking receipt processing debugging)
**Created**: 2026-02-05
**Related**: INFRA-001 (Azure Deployment), AI-003 (Receipt Scanning)

## Overview

This spec addresses integration issues between the Elixir app and Python receipt processing service by implementing:
1. **Tidewave Python** - AI-assisted debugging for Python service
2. **Full-stack observability** - OTEL with local Grafana stack (dev) / Application Insights (prod)
3. **Development-time issue detection** - Integration tests, health validation, contract testing, dev parity

This complements INFRA-001 (production Azure deployment) by focusing on local development observability.

---

## Architecture Overview

```
Development Environment (Docker Compose)
=========================================

[ Developer Machine ]
    |
    +-- docker-compose.yml
            |
            +-- elixir-app (Phoenix :4000)
            |       |
            |       +-- OTEL SDK -> Tempo (traces)
            |       +-- Logger -> Loki (logs)
            |       +-- Telemetry -> Prometheus (metrics)
            |       +-- Oban dashboard (web UI)
            |
            +-- python-service (FastAPI :8000)
            |       |
            |       +-- Tidewave (debug mode)
            |       +-- OTEL SDK -> Tempo
            |       +-- Structured logs -> Loki
            |
            +-- postgres:16 (:5432)
            |
            +-- Observability Stack (profile: observability)
                    |
                    +-- Grafana (:3001)
                    +-- Tempo (:4317 OTLP, :3200 API)
                    +-- Loki (:3100)
                    +-- Prometheus (:9090)

Trace Flow:
  Browser -> Elixir (trace starts)
      -> HTTP to Python (traceparent header propagated)
          -> Response
      <- Elixir completes span
  All spans -> Tempo -> Grafana (single correlated trace)
```

---

## 1. Tidewave Python Integration

**Purpose**: Enable AI-assisted debugging of the Python FastAPI service during development.

### Installation

**File**: `python_service/requirements.txt`
```
# Development debugging
tidewave>=0.1.0
```

**File**: `python_service/main.py`
```python
# After app creation, before middleware
if settings.DEBUG:
    try:
        from tidewave import install
        install(app, sqlalchemy_engine=engine)
        logger.info("Tidewave debugging enabled")
    except ImportError:
        logger.debug("Tidewave not installed, skipping")
```

### Features Enabled

| Tool | Purpose | Example Use |
|------|---------|-------------|
| `get_logs` | Access server logs | "Show me recent errors" |
| `execute_sql_query` | Query artifact/job database | "Find failed jobs from today" |
| `project_eval` | Execute code in running server | "Check classifier model state" |
| `get_source_location` | Find code paths | "Where is categorization defined?" |
| `get_models` | Discover application modules | "List all endpoints" |

### Configuration

**File**: `python_service/config.py`
```python
class Settings(BaseSettings):
    DEBUG: bool = Field(default=False, env="DEBUG")
    TIDEWAVE_ENABLED: bool = Field(default=True, env="TIDEWAVE_ENABLED")
```

---

## 2. OpenTelemetry Instrumentation (Local Development)

### 2A: Elixir OTEL Setup

**File**: `mix.exs` (new deps)
```elixir
# Observability
{:opentelemetry_api, "~> 1.3"},
{:opentelemetry, "~> 1.4"},
{:opentelemetry_sdk, "~> 1.4"},
{:opentelemetry_exporter, "~> 1.7"},
{:opentelemetry_phoenix, "~> 1.2"},
{:opentelemetry_ecto, "~> 1.2"},
{:opentelemetry_oban, "~> 1.1"},
{:opentelemetry_req, "~> 0.2"},
{:opentelemetry_cowboy, "~> 0.3"},
```

**File**: `config/dev.exs`
```elixir
# OpenTelemetry for local development
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_endpoint: "http://localhost:4317"
```

**File**: `lib/grocery_planner/application.ex`
```elixir
def start(_type, _args) do
  # Initialize OTEL instrumentation
  OpentelemetryPhoenix.setup(adapter: :cowboy2)
  OpentelemetryEcto.setup([:grocery_planner, :repo])
  OpentelemetryOban.setup()

  children = [...]
end
```

**File**: `lib/grocery_planner/ai_client.ex` (trace propagation)
```elixir
defp build_request(endpoint, payload, opts) do
  Req.new(
    base_url: base_url(),
    url: endpoint,
    method: :post,
    json: payload,
    receive_timeout: opts[:receive_timeout] || @default_timeout
  )
  |> Req.Request.append_request_steps(
    # opentelemetry_req adds traceparent automatically
    otel: &OpentelemetryReq.attach/1
  )
end
```

### 2B: Python OTEL Setup

**File**: `python_service/requirements.txt`
```
# OpenTelemetry
opentelemetry-api>=1.24.0
opentelemetry-sdk>=1.24.0
opentelemetry-exporter-otlp-proto-grpc>=1.24.0
opentelemetry-instrumentation-fastapi>=0.45b0
opentelemetry-instrumentation-sqlalchemy>=0.45b0
opentelemetry-instrumentation-logging>=0.45b0
```

**File**: `python_service/telemetry.py` (new file)
```python
"""OpenTelemetry instrumentation setup."""
import os
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor
from opentelemetry.sdk.resources import Resource


def setup_telemetry(app, engine=None):
    """Initialize OpenTelemetry with OTLP exporter."""
    endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")

    resource = Resource.create({
        "service.name": "grocery-planner-ai",
        "service.version": "1.0.0",
    })

    provider = TracerProvider(resource=resource)
    processor = BatchSpanProcessor(OTLPSpanExporter(endpoint=endpoint, insecure=True))
    provider.add_span_processor(processor)
    trace.set_tracer_provider(provider)

    # Auto-instrument FastAPI
    FastAPIInstrumentor.instrument_app(app)

    # Auto-instrument SQLAlchemy
    if engine:
        SQLAlchemyInstrumentor().instrument(engine=engine)

    # Add trace_id to logs
    LoggingInstrumentor().instrument(set_logging_format=True)
```

**File**: `python_service/main.py` (lifespan update)
```python
from telemetry import setup_telemetry

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize telemetry first
    if settings.OTEL_ENABLED:
        from database import engine
        setup_telemetry(app, engine)
        logger.info("OpenTelemetry initialized")

    # ... rest of startup
```

**File**: `python_service/middleware.py` (add trace context to logs)
```python
from opentelemetry import trace

class StructuredLogger(logging.Formatter):
    def format(self, record):
        # Get current span context
        span = trace.get_current_span()
        ctx = span.get_span_context() if span else None

        log_record = {
            "timestamp": ...,
            "level": ...,
            "message": ...,
            # Add trace context
            "trace_id": format(ctx.trace_id, '032x') if ctx and ctx.is_valid else None,
            "span_id": format(ctx.span_id, '016x') if ctx and ctx.is_valid else None,
        }
```

### 2C: Custom Spans for AI Operations

**File**: `python_service/main.py`
```python
from opentelemetry import trace

tracer = trace.get_tracer("grocery-planner-ai")

@app.post("/api/v1/categorize")
async def categorize_item(request: BaseRequest, db: Session = Depends(get_db)):
    with tracer.start_as_current_span("categorize_item") as span:
        span.set_attribute("item_name", payload.item_name)
        span.set_attribute("candidate_labels_count", len(payload.candidate_labels))

        # ... existing logic

        span.set_attribute("predicted_category", predicted_category)
        span.set_attribute("confidence", confidence)
```

---

## 3. Grafana Observability Stack (Local)

**File**: `docker-compose.observability.yml`
```yaml
version: "3.8"

services:
  tempo:
    image: grafana/tempo:2.3.1
    command: ["-config.file=/etc/tempo.yaml"]
    volumes:
      - ./config/tempo/tempo.yaml:/etc/tempo.yaml
      - tempo-data:/var/tempo
    ports:
      - "4317:4317"   # OTLP gRPC
      - "3200:3200"   # Tempo API

  loki:
    image: grafana/loki:2.9.3
    command: ["-config.file=/etc/loki/local-config.yaml"]
    ports:
      - "3100:3100"
    volumes:
      - loki-data:/loki

  prometheus:
    image: prom/prometheus:v2.48.1
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
    volumes:
      - ./config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:10.2.3
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
    volumes:
      - ./config/grafana/provisioning:/etc/grafana/provisioning
      - ./config/grafana/dashboards:/var/lib/grafana/dashboards
      - grafana-data:/var/lib/grafana
    ports:
      - "3001:3000"
    depends_on:
      - tempo
      - loki
      - prometheus

volumes:
  tempo-data:
  loki-data:
  prometheus-data:
  grafana-data:
```

### Pre-configured Dashboards

**File**: `config/grafana/dashboards/service-overview.json`

Panels:
- Request rate by service (Elixir, Python)
- P50/P95/P99 latency
- Error rate percentage
- Oban job queue depth
- Oban job success/failure rate
- AI service operation latency (categorize, OCR, embed)
- Database query latency

**File**: `config/grafana/dashboards/trace-explorer.json`

- Service map visualization
- Trace search by service, operation, duration
- Error traces highlighted
- Span details with attributes

---

## 4. Health Checks & Startup Validation

### 4A: Enhanced Python Health Endpoint

**File**: `python_service/main.py`
```python
@app.get("/health")
def health_check():
    """Basic health check for load balancers."""
    return {"status": "ok", "service": "grocery-planner-ai", "version": "1.0.0"}


@app.get("/health/ready")
def readiness_check(db: Session = Depends(get_db)):
    """Full readiness check with dependency validation."""
    checks = {}

    # Database connectivity
    try:
        db.execute(text("SELECT 1"))
        checks["database"] = {"status": "ok"}
    except Exception as e:
        checks["database"] = {"status": "error", "error": str(e)}

    # Classification model loaded
    checks["classifier"] = {
        "status": "ok" if classifier is not None else "not_loaded",
        "model": settings.CLASSIFICATION_MODEL if classifier else None
    }

    # Embedding model (lazy-loaded, check if importable)
    try:
        from sentence_transformers import SentenceTransformer
        checks["embedding_model"] = {"status": "available"}
    except ImportError:
        checks["embedding_model"] = {"status": "not_installed"}

    overall = "ok" if all(
        c.get("status") in ("ok", "available", "not_loaded")
        for c in checks.values()
    ) else "degraded"

    return {
        "status": overall,
        "checks": checks,
        "version": "1.0.0"
    }


@app.get("/health/live")
def liveness_check():
    """Simple liveness probe."""
    return {"status": "ok"}
```

### 4B: Elixir Startup Validation

**File**: `lib/grocery_planner/ai_client.ex`
```elixir
@doc """
Check if the AI service is healthy and responding.
"""
def health_check do
  case Req.get(base_url() <> "/health/ready", receive_timeout: 5_000) do
    {:ok, %{status: 200, body: body}} ->
      {:ok, body}
    {:ok, %{status: status, body: body}} ->
      {:error, {:unhealthy, status, body}}
    {:error, reason} ->
      {:error, {:connection_failed, reason}}
  end
end
```

**File**: `lib/grocery_planner/application.ex`
```elixir
def start(_type, _args) do
  # OTEL setup first
  setup_telemetry()

  children = [
    GroceryPlannerWeb.Telemetry,
    GroceryPlanner.Repo,
    {Oban, Application.fetch_env!(:grocery_planner, Oban)},
    # ... other children
  ]

  # Validate AI service connectivity after supervision tree starts
  # (non-blocking by default, configurable to fail-fast)
  Task.start(fn ->
    Process.sleep(2_000)  # Wait for services to initialize
    validate_ai_service()
  end)

  opts = [strategy: :one_for_one, name: GroceryPlanner.Supervisor]
  Supervisor.start_link(children, opts)
end

defp validate_ai_service do
  require_ai_service? = Application.get_env(:grocery_planner, :require_ai_service, false)

  case GroceryPlanner.AIClient.health_check() do
    {:ok, %{"status" => "ok"} = body} ->
      Logger.info("AI service connected: #{inspect(body)}")

    {:ok, %{"status" => "degraded"} = body} ->
      Logger.warning("AI service degraded: #{inspect(body)}")

    {:error, reason} ->
      if require_ai_service? do
        Logger.error("AI service unavailable (required): #{inspect(reason)}")
        System.stop(1)
      else
        Logger.warning("AI service unavailable: #{inspect(reason)}. AI features disabled.")
      end
  end
end
```

### 4C: Enhanced Elixir Health Endpoint

**File**: `lib/grocery_planner_web/controllers/health_controller.ex`
```elixir
defmodule GroceryPlannerWeb.HealthController do
  use GroceryPlannerWeb, :controller

  def index(conn, _params) do
    checks = %{
      database: check_database(),
      ai_service: check_ai_service(),
      oban: check_oban()
    }

    status = determine_status(checks)

    conn
    |> put_status(if status == "ok", do: 200, else: 503)
    |> json(%{
      status: status,
      services: checks,
      version: Application.spec(:grocery_planner, :vsn) |> to_string()
    })
  end

  defp check_database do
    case Ecto.Adapters.SQL.query(GroceryPlanner.Repo, "SELECT 1", []) do
      {:ok, _} -> %{status: "ok"}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end

  defp check_ai_service do
    case GroceryPlanner.AIClient.health_check() do
      {:ok, body} -> %{status: body["status"], details: body["checks"]}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end

  defp check_oban do
    queues = Oban.check_queue(:ai_jobs)
    %{
      status: "ok",
      queues: %{
        ai_jobs: queues
      }
    }
  rescue
    _ -> %{status: "error"}
  end

  defp determine_status(checks) do
    cond do
      checks.database.status != "ok" -> "error"
      checks.ai_service.status == "error" -> "degraded"
      true -> "ok"
    end
  end
end
```

---

## 5. Integration Tests

### 5A: Elixir Integration Test Suite

**File**: `test/integration/ai_service_test.exs`
```elixir
defmodule GroceryPlanner.Integration.AIServiceTest do
  use GroceryPlanner.DataCase, async: false

  @moduletag :integration

  describe "receipt processing end-to-end" do
    setup do
      # Ensure AI service is running
      case GroceryPlanner.AIClient.health_check() do
        {:ok, _} -> :ok
        {:error, reason} ->
          ExUnit.skip("AI service unavailable: #{inspect(reason)}")
      end
    end

    test "processes receipt image and extracts items" do
      account = insert(:account)
      user = insert(:user, account: account)

      # Upload a test receipt image
      {:ok, receipt} = GroceryPlanner.Inventory.create_receipt(%{
        account_id: account.id,
        user_id: user.id,
        image_path: "test/fixtures/receipts/sample_receipt.png",
        status: :pending
      })

      # Process via Oban job
      assert {:ok, _job} = Oban.insert(
        GroceryPlanner.Workers.ReceiptProcessWorker.new(%{id: receipt.id})
      )

      # Wait for processing (with timeout)
      assert_eventually(fn ->
        updated = GroceryPlanner.Inventory.get_receipt!(receipt.id)
        updated.status == :completed
      end, timeout: 30_000)

      # Verify extraction results
      receipt = GroceryPlanner.Inventory.get_receipt!(receipt.id)
      assert receipt.merchant != nil
      assert length(receipt.line_items) > 0
    end
  end

  describe "categorization" do
    test "categorizes grocery items" do
      context = %{tenant_id: "test", user_id: "test-user"}

      {:ok, result} = GroceryPlanner.AIClient.categorize(
        "Organic Bananas",
        ["Produce", "Dairy", "Bakery", "Meat"],
        context
      )

      assert result["category"] == "Produce"
      assert result["confidence"] > 0.5
    end
  end
end
```

### 5B: CI Workflow

**File**: `.github/workflows/integration.yml`
```yaml
name: Integration Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  integration:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: grocery_planner_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.17'
          otp-version: '27'

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.13'

      - name: Install Python dependencies
        run: |
          cd python_service
          pip install -r requirements.txt

      - name: Start Python service
        run: |
          cd python_service
          uvicorn main:app --host 0.0.0.0 --port 8000 &
          sleep 10  # Wait for startup
        env:
          USE_REAL_CLASSIFICATION: "false"
          USE_TESSERACT_OCR: "false"

      - name: Verify Python service health
        run: curl -f http://localhost:8000/health

      - name: Install Elixir dependencies
        run: mix deps.get

      - name: Setup database
        run: mix ash.setup
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost/grocery_planner_test

      - name: Run integration tests
        run: mix test test/integration/ --include integration
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost/grocery_planner_test
          AI_SERVICE_URL: http://localhost:8000
```

---

## 6. Contract Testing

### 6A: Schema Validation Module

**File**: `lib/grocery_planner/ai_client/contracts.ex`
```elixir
defmodule GroceryPlanner.AIClient.Contracts do
  @moduledoc """
  Contract definitions for AI service API.
  Used for response validation and documentation.
  """

  defmodule CategorizationResponse do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :category, :string
      field :confidence, :float
      field :confidence_level, :string
      field :all_scores, :map
      field :processing_time_ms, :float
    end

    def validate(data) when is_map(data) do
      %__MODULE__{}
      |> cast(data, [:category, :confidence, :confidence_level, :all_scores, :processing_time_ms])
      |> validate_required([:category, :confidence])
      |> validate_number(:confidence, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
      |> validate_inclusion(:confidence_level, ["high", "medium", "low"])
      |> apply_action(:validate)
    end
  end

  # Add more contract schemas...
end
```

### 6B: Contract Test

**File**: `test/integration/contracts_test.exs`
```elixir
defmodule GroceryPlanner.Integration.ContractsTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  describe "API contract validation" do
    test "categorization response matches contract" do
      context = %{tenant_id: "test", user_id: "test-user"}

      {:ok, response} = GroceryPlanner.AIClient.categorize(
        "Milk",
        ["Produce", "Dairy", "Bakery"],
        context
      )

      assert {:ok, _validated} =
        GroceryPlanner.AIClient.Contracts.CategorizationResponse.validate(response)
    end
  end
end
```

---

## 7. Development Environment Parity

### 7A: Full Stack Docker Compose

**File**: `docker-compose.yml`
```yaml
version: "3.8"

services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: grocery_planner_dev
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  python-service:
    build:
      context: ./python_service
      dockerfile: Dockerfile
    environment:
      DEBUG: "true"
      OTEL_ENABLED: "true"
      OTEL_EXPORTER_OTLP_ENDPOINT: "http://tempo:4317"
      USE_REAL_CLASSIFICATION: "false"
      USE_TESSERACT_OCR: "true"
    ports:
      - "8000:8000"
    volumes:
      - ./python_service:/app
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 10s
      timeout: 5s
      retries: 3

  elixir-app:
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      DATABASE_URL: postgres://postgres:postgres@postgres:5432/grocery_planner_dev
      AI_SERVICE_URL: http://python-service:8000
      PHX_HOST: localhost
      SECRET_KEY_BASE: "dev-secret-key-base-at-least-64-bytes-long-for-development-only"
      OTEL_EXPORTER_OTLP_ENDPOINT: "http://tempo:4317"
    ports:
      - "4000:4000"
    depends_on:
      postgres:
        condition: service_healthy
      python-service:
        condition: service_healthy
    command: >
      sh -c "mix ash.setup && mix phx.server"

volumes:
  postgres-data:

# Include observability stack with: docker compose --profile observability up
```

### 7B: Development Scripts

**File**: `bin/dev`
```bash
#!/bin/bash
set -e

echo "Starting development environment..."

# Start dependencies
docker compose up -d postgres python-service

# Wait for services
echo "Waiting for services..."
until curl -sf http://localhost:8000/health > /dev/null; do
  sleep 1
done
echo "Python service ready"

# Start Elixir app locally (for better DX with code reload)
echo "Starting Elixir app..."
iex -S mix phx.server
```

**File**: `bin/dev-full`
```bash
#!/bin/bash
set -e

echo "Starting full development environment with observability..."
docker compose -f docker-compose.yml -f docker-compose.observability.yml up -d

echo ""
echo "Services available at:"
echo "  - Elixir app:     http://localhost:4000"
echo "  - Python service: http://localhost:8000"
echo "  - Grafana:        http://localhost:3001"
echo "  - Prometheus:     http://localhost:9090"
```

**File**: `bin/test-integration`
```bash
#!/bin/bash
set -e

echo "Starting services for integration tests..."
docker compose up -d postgres python-service

echo "Waiting for services..."
until curl -sf http://localhost:8000/health > /dev/null; do
  sleep 1
done

echo "Running integration tests..."
mix test test/integration/ --include integration

echo "Stopping services..."
docker compose down
```

---

## 8. Implementation Phases

| Phase | Tasks | Effort | Impact |
|-------|-------|--------|--------|
| **1** | Health checks (4A, 4B, 4C) | 1 day | High - immediate visibility | **DONE** |
| **2** | Tidewave integration (1) | 0.5 day | Medium - debugging capability |
| **3** | Docker Compose (7A, 7B) | 1 day | High - dev parity |
| **4** | OTEL instrumentation (2A, 2B, 2C) | 2 days | High - distributed tracing |
| **5** | Grafana stack (3) | 1 day | High - visualization |
| **6** | Integration tests (5A, 5B) | 1.5 days | High - CI safety |
| **7** | Contract testing (6A, 6B) | 0.5 day | Medium - API safety | **DONE** |

**Total estimated effort**: ~7.5 days

---

## Critical Files Summary

### Files to Modify

| File | Changes |
|------|---------|
| `mix.exs` | Add OTEL deps |
| `config/dev.exs` | OTEL exporter config |
| `lib/grocery_planner/application.ex` | OTEL setup, startup validation |
| `lib/grocery_planner/ai_client.ex` | Health check function, trace propagation |
| `lib/grocery_planner_web/controllers/health_controller.ex` | Enhanced health endpoint |
| `python_service/requirements.txt` | Add tidewave, OTEL deps |
| `python_service/config.py` | OTEL settings |
| `python_service/main.py` | Tidewave install, enhanced health, OTEL init |
| `python_service/middleware.py` | Trace context in logs |

### Files to Create

| File | Purpose |
|------|---------|
| `python_service/telemetry.py` | OTEL setup module |
| `docker-compose.yml` | Full stack dev environment |
| `docker-compose.observability.yml` | Grafana stack |
| `config/grafana/` | Dashboard provisioning |
| `config/tempo/tempo.yaml` | Tempo configuration |
| `config/prometheus/prometheus.yml` | Prometheus scrape config |
| `test/integration/ai_service_test.exs` | Integration tests |
| `test/integration/contracts_test.exs` | Contract tests |
| `lib/grocery_planner/ai_client/contracts.ex` | API contracts |
| `.github/workflows/integration.yml` | CI workflow |
| `bin/dev`, `bin/dev-full`, `bin/test-integration` | Dev scripts |

---

## Verification

1. **Health checks work:**
   ```bash
   curl http://localhost:4000/health_check | jq
   curl http://localhost:8000/health/ready | jq
   ```

2. **Tidewave debugging:**
   - Start Python service with `DEBUG=true`
   - Use AI assistant to query logs, execute SQL, inspect state

3. **Traces in Grafana:**
   ```bash
   bin/dev-full
   # Upload a receipt via web UI
   # Open http://localhost:3001 -> Explore -> Tempo
   # Search for traces spanning elixir-app -> python-service
   ```

4. **Oban metrics visible:**
   - Check http://localhost:9090 for `oban_job_*` metrics
   - See queue depth in Grafana dashboard

5. **Integration tests pass:**
   ```bash
   bin/test-integration
   ```

6. **Startup validation:**
   ```bash
   docker compose stop python-service
   mix phx.server  # Should log warning about AI service
   ```
