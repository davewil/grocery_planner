# INFRA-001: Azure Deployment

**Status**: PLANNED
**Priority**: Future work
**Created**: 2026-02-04
**Related**: INFRA-002 (Observability & Developer Experience)

## Architecture Overview

```
Internet (HTTPS)
    |
    v
[ Azure Container Apps Environment ]
    |
    +-- ca-grocery-planner-web (Elixir/Phoenix, External Ingress :8080)
    |       |
    |       +-- Oban workers (in-process, PostgreSQL-backed)
    |       +-- LiveView (PubSub, single-node)
    |       +-- OTEL SDK -> Grafana Cloud (or self-hosted)
    |
    +-- ca-grocery-planner-ai (Python/FastAPI, Internal Only :8000)
            |
            +-- Tesseract OCR (CPU)
            +-- Zero-shot classification (CPU, local model)
            +-- OTEL SDK -> Grafana Cloud (or self-hosted)

External Services:
    +-- Azure PostgreSQL Flexible Server (pgvector, citext)
    +-- Azure Blob Storage (receipt images)
    +-- Azure Key Vault (secrets)
    +-- Azure Container Registry (Docker images)
    +-- Grafana Cloud (traces: Tempo, logs: Loki, metrics: Prometheus)
    +-- Azure OpenAI (Phase 2: embeddings)
```

---

## 1. Azure Services

| Service | SKU / Tier | Purpose | Est. Cost/mo |
|---------|-----------|---------|-------------|
| **Container Apps Environment** | Consumption | Shared env for both apps | (included) |
| **Container App: Elixir** | 0.5 vCPU, 1 Gi, 1-3 replicas | Phoenix + Oban | ~$25-35 |
| **Container App: Python** | 1.0 vCPU, 2 Gi, 0-2 replicas | AI service (scale-to-zero) | ~$15-40 |
| **PostgreSQL Flexible Server** | Burstable B1ms, 32 GB | Primary database | ~$30-40 |
| **Blob Storage** | Standard LRS | Receipt images | ~$2 |
| **Container Registry** | Basic | Docker image hosting | ~$5 |
| **Key Vault** | Standard | Secrets management | ~$1 |
| **Grafana Cloud** | Free tier (50GB traces, 50GB logs, 10k metrics) | Observability stack | ~$0 |
| **Azure OpenAI** (Phase 2) | text-embedding-3-small | Embeddings API | ~$5-20 |
| **Total** | | | **~$78-143/mo** |

> **Note**: Using Grafana Cloud free tier for observability. For higher volumes, consider:
> - Grafana Cloud Pro (~$50/mo) for increased limits
> - Self-hosted Grafana stack on a small VM (~$20-40/mo) for unlimited data

### Container App: Elixir (`ca-grocery-planner-web`)

- **Ingress**: External, HTTPS with auto-managed TLS, port 8080
- **Scaling**: Min 1 (LiveView needs persistent connection), Max 3, scale on HTTP concurrency (100)
- **Init container**: Runs `/app/bin/migrate` before main container
- **Health probes**:
  - Startup: `GET /health`, period 2s, failure threshold 30
  - Liveness: `GET /health`, period 30s
  - Readiness: `GET /health`, initial delay 10s
- **Env vars**: `DATABASE_URL`, `SECRET_KEY_BASE`, `AI_SERVICE_URL=http://ca-grocery-planner-ai:8000`, `PHX_HOST`, `AZURE_STORAGE_CONNECTION_STRING`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_HEADERS` (all from Key Vault)

### Container App: Python (`ca-grocery-planner-ai`)

- **Ingress**: Internal only (unreachable from internet), port 8000
- **Scaling**: Min 0 (scale-to-zero), Max 2, scale on HTTP concurrency (10)
- **Health probes**:
  - Startup: `GET /health`, period 3s, failure threshold 60 (models take ~2 min to load)
  - Liveness: `GET /health`, period 30s
  - Readiness: `GET /health`, initial delay 60s
- **Note**: Image ~2-3 GB (pre-baked ML models), cold start ~2 min

### PostgreSQL Flexible Server

- Version: 16 (latest Azure supports; pgvector available)
- Extensions: `pgvector`, `citext`, `uuid-ossp`, `ash-functions`
- Storage: 32 GB, auto-grow enabled
- Backup: 7-day retention (free)
- HA: Disabled (budget)
- Access: Firewall rules (allow Azure services), SSL required

### Blob Storage

- Replaces local `priv/uploads/receipts/` filesystem storage
- Private container `receipts`, Hot access tier
- New Elixir module `GroceryPlanner.Storage` with behaviour:
  - `GroceryPlanner.Storage.Local` (dev/test)
  - `GroceryPlanner.Storage.AzureBlob` (production)
- `ReceiptProcessor.store_file/1` and `ProcessReceipt` change updated to use Storage abstraction

---

## 2. Networking

```
Internet -> HTTPS -> ca-grocery-planner-web (External)
                         |
                         | HTTP (internal DNS)
                         v
                     ca-grocery-planner-ai (Internal only)

PostgreSQL: Firewall (Azure services only) + SSL required
Blob Storage: Private, connection string auth
Key Vault: Managed identity access
```

- Container Apps managed VNet handles inter-service communication
- No custom VNet needed (budget optimization)
- Python AI service has no public endpoint

---

## 3. OpenTelemetry Integration

> **See also**: INFRA-002 for detailed OTEL setup including local development with self-hosted Grafana stack.

### Elixir OTEL

**New deps in `mix.exs`:**
```elixir
{:opentelemetry_api, "~> 1.3"},
{:opentelemetry, "~> 1.4"},
{:opentelemetry_sdk, "~> 1.4"},
{:opentelemetry_exporter, "~> 1.7"},
{:opentelemetry_phoenix, "~> 1.2"},
{:opentelemetry_ecto, "~> 1.2"},
{:opentelemetry_oban, "~> 1.1"},
{:opentelemetry_req, "~> 0.2"},
{:logger_json, "~> 6.0"},
```

**Instrumentation in `application.ex`:**
```elixir
OpentelemetryPhoenix.setup()
OpentelemetryEcto.setup([:grocery_planner, :repo])
OpentelemetryOban.setup()
```

**Production config** (`config/prod.exs`):
```elixir
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT"),
  otlp_headers: System.get_env("OTEL_EXPORTER_OTLP_HEADERS")  # For Grafana Cloud auth
```

**Structured JSON logging** via `logger_json` in `config/prod.exs`

**Custom spans** for receipt processing and AI client calls

**Trace propagation**: `opentelemetry_req` automatically attaches W3C `traceparent`/`tracestate` headers on outbound HTTP to Python service

### Python OTEL

**New deps in `requirements.txt`:**
```
opentelemetry-api>=1.24.0
opentelemetry-sdk>=1.24.0
opentelemetry-exporter-otlp-proto-grpc>=1.24.0
opentelemetry-instrumentation-fastapi>=0.45b0
opentelemetry-instrumentation-sqlalchemy>=0.45b0
opentelemetry-instrumentation-logging>=0.45b0
```

**Instrumentation in `main.py` lifespan**: FastAPIInstrumentor auto-instruments all endpoints

**Enhance `StructuredLogger`** in `middleware.py` with `trace_id` and `span_id` from current span context

### Grafana Cloud Configuration

For production, use Grafana Cloud OTLP endpoint:
- **Endpoint**: `https://otlp-gateway-prod-us-east-0.grafana.net/otlp`
- **Auth**: Basic auth via `OTEL_EXPORTER_OTLP_HEADERS` (Instance ID + API key from Grafana Cloud)
- Store credentials in Azure Key Vault

### Distributed Tracing

Elixir propagates W3C Trace Context headers -> Python reads them automatically via FastAPI instrumentation. A single user request produces a correlated trace spanning both services visible in Grafana Tempo.

---

## 4. Monitoring & Alerting (Grafana)

> **See also**: INFRA-002 for local development dashboards and self-hosted Grafana stack setup.

### Alert Rules (Grafana Alerting)

| Alert | Signal | Threshold | Severity | Notify |
|-------|--------|-----------|----------|--------|
| **High Error Rate** | HTTP 5xx | > 5% over 5 min | Critical | Email + PagerDuty |
| **High Latency** | P95 response time | > 5s over 5 min | Warning | Email |
| **AI Service Down** | Health check fail | > 3 consecutive | Critical | Email + PagerDuty |
| **DB Connection Pool** | Ecto queue_time | P95 > 500ms over 5 min | Warning | Email |
| **DB High CPU** | PostgreSQL CPU | > 80% over 10 min | Warning | Email |
| **Oban Job Failures** | Job failure count | > 10 in 15 min | Warning | Email |
| **Receipt Queue Backlog** | Pending receipts | > 20 | Info | Email |
| **Memory Pressure** | Container memory | > 85% of limit | Warning | Email |

### Contact Points (Grafana)

- **`email-oncall`**: Email to on-call engineer (all severities)
- **`pagerduty`**: PagerDuty integration (Critical only)
- **`slack-alerts`**: Slack channel for Warning/Info alerts

### Custom Telemetry Events

Elixir:
- `grocery_planner.ai_client.request.duration` (tags: endpoint, status)
- `grocery_planner.receipt.processing.duration` (tags: status)
- `grocery_planner.receipt.queue.depth` (gauge)

Python:
- `ai_service.categorize.duration` (tags: model, confidence)
- `ai_service.embed.duration` (tags: batch_size)
- `ai_service.ocr.duration` (tags: engine)

### Grafana Dashboards

Provisioned dashboards in Grafana Cloud:

**Service Overview Dashboard:**
- Request volume and latency (both services)
- Error rates by endpoint
- AI service performance distribution
- Oban queue depth and failure rates

**Infrastructure Dashboard:**
- Container CPU/memory utilization (from Azure metrics)
- PostgreSQL connections and query latency
- Blob storage operations

**Trace Explorer:**
- Distributed trace search via Tempo
- Service map visualization
- Error trace drill-down

---

## 5. Service Degradation & On-Call

### Circuit Breaker (Elixir AiClient)

Add `{:fuse, "~> 2.5"}` to mix.exs. Configure in `AiClient`:
- **Threshold**: 5 failures in 60s -> circuit opens
- **Cooldown**: 30s -> half-open (probe with 1 request)
- **Fallback**: `{:error, :circuit_open}` returned immediately

### Graceful Degradation

Feature flags already exist (`AI_CATEGORIZATION_ENABLED`, etc.). Add runtime degradation:
- When circuit open: AI features show "temporarily unavailable" in LiveView
- Receipt processing: Oban retries later when circuit recovers
- Categorization: Falls back to uncategorized items
- Search: Falls back to text-only search (no embeddings)

### Health Check Cascade

New `GET /health` endpoint on Elixir app:
```json
// Healthy
{"status": "ok", "database": "ok", "ai_service": "ok"}

// Degraded (still passes liveness, fires alerts)
{"status": "degraded", "database": "ok", "ai_service": "down"}
```

### On-Call Notification Flow

```
Alert fires (Grafana Alerting)
    -> Notification Policy (route by severity)
        -> Critical: PagerDuty + Email
        -> Warning: Slack #alerts + Email
        -> Info: Slack #alerts only
    -> PagerDuty
        -> Pages on-call engineer (Critical)
        -> Creates incident ticket
```

---

## 6. Production Dockerfiles

### `Dockerfile.prod` (Elixir)

Key changes from current `Dockerfile`:
- Update to Elixir 1.19.4 / OTP 28.0 / Debian bookworm
- Add `curl` in runner for health checks
- Add `HEALTHCHECK` instruction
- Add `EXPOSE 8080`

### `python_service/Dockerfile.prod` (Python)

Key changes from current `Dockerfile`:
- Multi-stage build (builder + runtime)
- Add `tesseract-ocr` system dependency
- **Pre-bake ML models** during Docker build (cache in image layer):
  - `all-MiniLM-L6-v2` (~80 MB)
  - `valhalla/distilbart-mnli-12-3` (~300 MB)
- Add `HEALTHCHECK` instruction with 120s start period (model loading)
- Set `TRANSFORMERS_CACHE` / `HF_HOME` env vars

---

## 7. CI/CD Pipeline

### GitHub Actions: `.github/workflows/deploy-azure.yml`

```
CI passes (existing workflow)
    -> Trigger deploy workflow
        -> Build & push Elixir image to ACR
        -> Build & push Python image to ACR
        -> Deploy Elixir Container App (with init container for migrations)
        -> Deploy Python Container App
```

- Uses `azure/docker-login@v1` for ACR auth
- Uses `azure/container-apps-deploy-action@v1` for deployment
- Images tagged with `${{ github.sha }}` + `latest`
- Secrets: `ACR_USERNAME`, `ACR_PASSWORD`, `AZURE_CREDENTIALS` in GitHub

---

## 8. Implementation Phases

### Phase 1: Infrastructure + Dockerfiles
- Create Azure resources (Resource Group, ACR, Key Vault, PostgreSQL, Blob Storage, Container Apps Environment)
- Set up Grafana Cloud account (free tier) or provision self-hosted Grafana stack
- Create `Dockerfile.prod` for Elixir
- Create `Dockerfile.prod` for Python (multi-stage with pre-baked models)
- Implement `GroceryPlanner.Storage` behaviour + AzureBlob adapter
- Add `/health` endpoint to Elixir app

### Phase 2: OTEL + Observability
- Add OTEL deps to both services
- Instrument Phoenix, Ecto, Oban, Req (Elixir)
- Instrument FastAPI (Python)
- Configure OTLP exporter to Grafana Cloud (Tempo for traces, Loki for logs)
- Switch to structured JSON logging in prod
- Add trace context to Python StructuredLogger

### Phase 3: Deployment Pipeline
- Create `deploy-azure.yml` GitHub Actions workflow
- Configure Container Apps (scaling, health probes, init containers)
- Set up Key Vault secret references (including Grafana Cloud OTLP credentials)
- Test staging deployment

### Phase 4: Monitoring + Alerting
- Create alert rules in Grafana Alerting
- Configure contact points (email, PagerDuty, Slack)
- Build Grafana dashboards (Service Overview, Infrastructure, Trace Explorer)
- Implement circuit breaker in AiClient
- Test degradation scenarios end-to-end

### Phase 5: Azure OpenAI Migration (future)
- Provision Azure OpenAI with `text-embedding-3-small`
- Feature-flag embedding backend (local vs Azure OpenAI)
- Migrate pgvector dimensions if switching models (384 -> 1536)

---

## Critical Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `Dockerfile.prod` | Create | Production Elixir image |
| `python_service/Dockerfile.prod` | Create | Production Python image with pre-baked models |
| `.github/workflows/deploy-azure.yml` | Create | Azure CD pipeline |
| `lib/grocery_planner/storage.ex` | Create | Storage behaviour |
| `lib/grocery_planner/storage/local.ex` | Create | Local filesystem adapter |
| `lib/grocery_planner/storage/azure_blob.ex` | Create | Azure Blob adapter |
| `lib/grocery_planner_web/controllers/health_controller.ex` | Create | Health check cascade |
| `lib/grocery_planner/ai_client.ex` | Modify | Add circuit breaker + OTEL |
| `lib/grocery_planner/inventory/receipt_processor.ex` | Modify | Use Storage behaviour |
| `lib/grocery_planner/inventory/changes/process_receipt.ex` | Modify | Fetch from Blob |
| `lib/grocery_planner/application.ex` | Modify | OTEL instrumentation setup |
| `config/runtime.exs` | Modify | Azure env vars |
| `config/prod.exs` | Modify | OTEL + JSON logging config |
| `mix.exs` | Modify | OTEL + fuse + logger_json deps |
| `python_service/requirements.txt` | Modify | OTEL deps |
| `python_service/main.py` | Modify | OTEL instrumentation |
| `python_service/middleware.py` | Modify | Trace context in logs |

## Verification

- Build both Dockerfiles locally: `docker build -f Dockerfile.prod .` and `docker build -f python_service/Dockerfile.prod python_service/`
- Run `docker compose` with production-like config to verify inter-service communication
- `mix test` passes with Storage behaviour (local adapter in test)
- Deploy to staging Container Apps Environment, verify health checks
- Verify OTEL traces appear in Grafana Cloud Tempo (or self-hosted Tempo)
- Check logs flow to Grafana Cloud Loki
- Verify Grafana dashboards show metrics from both services
- Simulate AI service failure, verify circuit breaker triggers and Grafana alerts fire
