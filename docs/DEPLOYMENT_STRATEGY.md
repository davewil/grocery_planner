# Deployment & CI/CD Strategy

## Executive Summary
**Provider**: [Fly.io](https://fly.io)
**Orchestration**: Firecracker MicroVMs (Docker-based)
**CI/CD**: GitHub Actions
**Database**: Fly Postgres (High Availability) with `pgvector` extension

## Architecture Overview

We will deploy two distinct applications that communicate over a private internal network (IPv6).

1.  **`grocery-planner-web` (Elixir/Phoenix)**:
    *   The public-facing monolith.
    *   Handles UI, Auth, and Business Logic.
    *   Scales horizontally (connected via Erlang Distribution).
2.  **`grocery-planner-ai` (Python/FastAPI)**:
    *   Private-only API (not exposed to the public internet).
    *   Handles ML Inference (OCR, Embeddings, Z3 Solver).
    *   Scales independently based on CPU/GPU needs.
3.  **Database**:
    *   Shared PostgreSQL instance.
    *   Requires `pgvector` extension for semantic search.

## Hosting Strategy (Fly.io)

### Why Fly.io?
*   **Elixir Synergy**: Built-in support for clustering and LiveView websockets.
*   **Private Networking**: Applications in the same organization can talk securely via `http://<app-name>.internal`, perfect for the sidecar pattern.
*   **Postgres Extensions**: First-class support for enabling `pgvector`.
*   **Cost**: "Scale to Zero" capabilities for the AI service if it's expensive/infrequently used.

### Configuration
Each service will have its own `fly.toml`:
*   `fly.toml` (Root): For the Elixir app.
*   `python_service/fly.toml`: For the Python AI service.

## CI/CD Pipeline (GitHub Actions)

We will use **GitHub Actions** for automation.

### 1. Continuous Integration (`.github/workflows/ci.yml`)
Triggers on: `push` to `main`, `pull_request`.

**Jobs:**
*   **Elixir Test Suite**:
    *   Install OTP/Elixir.
    *   Cache `deps` and `_build`.
    *   Run `mix format --check-formatted`.
    *   Run `mix credo`.
    *   Run `mix test`.
*   **Python Test Suite**:
    *   Install Python 3.11+.
    *   Cache `pip` / `poetry` / `uv`.
    *   Run `ruff check` (Linting).
    *   Run `pytest` (Unit tests).

### 2. Continuous Deployment (`.github/workflows/deploy.yml`)
Triggers on: `push` to `main` (after CI passes).

**Jobs:**
*   **Deploy Elixir**:
    *   Uses `flyctl deploy --remote-only`.
    *   Builds Docker image.
    *   Runs `mix ecto.migrate`.
*   **Deploy Python**:
    *   Uses `flyctl deploy --config python_service/fly.toml`.

## Rollback & Reliability

*   **Blue/Green Deployment**: Fly.io performs rolling restarts. New VMs must pass health checks before traffic is routed.
*   **Rollback**:
    *   Manual: `fly deploy --image <previous-image-tag>` or via UI.
    *   Database: `fly pg create-snapshot` before major migrations.
*   **Health Checks**:
    *   Elixir: Endpoint `/health` checking DB connection.
    *   Python: Endpoint `/health` checking model loading status.

## Monitoring & Observability

1.  **Logs**: Aggregated logs via Fly.io (can pipe to Datadog/Logtail).
2.  **Metrics**:
    *   **Phoenix LiveDashboard**: Included in the app (protected by admin auth).
    *   **Prometheus**: Fly exposes metrics that can be scraped.
3.  **Error Tracking**:
    *   **Sentry**: Integrated into both Elixir (`sentry` package) and Python (`sentry-sdk`).

## Action Plan
1.  **Dockerize**:
    *   Review/Update Elixir `Dockerfile`.
    *   Create `python_service/Dockerfile`.
2.  **CI Setup**: Create `.github/workflows/ci.yml`.
3.  **Infrastructure Provisioning**: Run initial `fly launch` commands (locally or via script).
