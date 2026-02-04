# QA-001: E2E Integration Tests — Elixir ↔ Python Receipt OCR

## Overview

**Feature:** Two-tier integration testing for the Elixir-Python AI service pipeline
**Priority:** High
**Related:** AI-003 (Receipt Scanning)
**Epic:** QA (Quality Assurance)

## Problem Statement

The Elixir app and Python AI service communicate over HTTP but are tested in complete isolation. Elixir tests mock all Python calls via `Req.Test.stub`, and Python tests use FastAPI's in-process `TestClient`. There is no automated verification that the two services actually work together, nor any way to validate a deployment is correctly configured.

**Current Gaps:**
- No test exercises the real HTTP path from Elixir to Python
- No verification that request/response contracts match between services
- No smoke test for post-deployment validation (AWS/Azure)
- CI runs the two test suites independently with no cross-service testing

## Goal

Two-tier testing strategy providing:
1. **Local integration tests** — Verify the real Elixir→Python HTTP path works before commit/push
2. **Deployable smoke tests** — Verify correct configuration after cloud deployment (AWS/Azure)

## Architecture

```
Tier 1: Integration Tests (ExUnit, @moduletag :integration)
  - Python service started once per test run on port 8099
  - Real HTTP calls (no Req.Test stub)
  - Isolated via unique account_id per test + Ecto sandbox
  - Run with: ./scripts/test-integration.sh or mix test.integration

Tier 2: Smoke Tests (Mix task, no DB needed)
  - Runs against any deployed URL
  - Pure HTTP checks: health, endpoint reachability, round-trip OCR
  - Run with: mix smoke_test --url https://ai.staging.example.com
```

## Files to Create

| File | Purpose |
|------|---------|
| `test/support/integration_case.ex` | CaseTemplate: sandbox setup, override ai_client_opts to allow real HTTP, helper functions |
| `test/integration/receipt_ocr_integration_test.exs` | 4 test groups: connectivity, direct AiClient, full processing flow, error handling |
| `scripts/test-integration.sh` | Starts Python service, waits for health, runs `mix test.integration`, cleans up |
| `lib/mix/tasks/smoke_test.ex` | Standalone Mix task for post-deployment verification (no DB, pure HTTP) |

## Files to Modify

| File | Change |
|------|--------|
| `test/test_helper.exs` | `ExUnit.start(exclude: [:integration, :smoke])` — prevent integration tests from running during normal `mix test` |
| `mix.exs` | Add alias `"test.integration": ["ash.setup --quiet", "test --only integration"]` and `preferred_envs` entry |
| `.github/workflows/ci.yml` | Add `test-integration` job: install Python + Tesseract, start Python service, run integration tests. Re-enable `test-python` job. |

## Implementation Steps

### Step 1: Tag exclusion in test_helper.exs
Change `ExUnit.start()` to `ExUnit.start(exclude: [:integration, :smoke])`. This gates everything — normal `mix test` won't run integration tests.

### Step 2: Mix alias in mix.exs
Add `"test.integration"` alias that runs `ash.setup --quiet` then `test --only integration`. Add to `preferred_envs` as `:test`.

### Step 3: IntegrationCase (test/support/integration_case.ex)
ExUnit CaseTemplate that:
- Sets up Ecto sandbox (same as DataCase)
- Overrides `Application.get_env(:grocery_planner, :ai_client_opts)` to `[]` (removes Req.Test plug, enabling real HTTP)
- Restores original config in `on_exit`
- Provides `ai_service_url/0` helper (reads `AI_SERVICE_URL` env, defaults to `http://localhost:8099`)
- Provides `service_healthy?/0` helper

### Step 4: Integration tests (test/integration/receipt_ocr_integration_test.exs)
`@moduletag :integration`, `async: false`

**Test Group 1: Python service connectivity**
- Health check returns `{"status": "ok"}`

**Test Group 2: Direct AiClient.extract_receipt/3**
- Send real base64 image → validate response structure (items list, confidence scores)
- Send invalid base64 → verify error handling

**Test Group 3: Full receipt processing flow**
- Create receipt in DB with real file_path pointing to `test/fixtures/sample_receipt.png`
- Call `Ash.update` with `:process` action directly (bypasses Oban, exercises real ProcessReceipt change)
- Verify: receipt status changes to `:completed`, `processed_at` set, receipt_items created in DB
- Validate receipt item fields (raw_name, receipt_id)

**Test Group 4: Error handling**
- Receipt with non-existent file_path → verify graceful error

**Test isolation**: Each test creates its own account via `create_account()`. Ecto sandbox rolls back all DB changes. Python SQLite artifacts are tenant-scoped. `async: false` prevents concurrent test interference.

### Step 5: Integration test script (scripts/test-integration.sh)
Shell script that:
1. Checks prerequisites (uvicorn, tesseract)
2. Starts Python service on port 8099 if not already running
3. Polls `/health` with 30-attempt timeout
4. Runs `AI_SERVICE_URL=http://localhost:8099 mix test.integration`
5. Cleans up Python process on exit (trap)

### Step 6: Smoke test Mix task (lib/mix/tasks/smoke_test.ex)
`mix smoke_test [--url URL] [--verbose]`

Three checks:
1. **Health check** — `GET /health` returns 200 with `status: "ok"`
2. **Endpoint reachability** — `POST /api/v1/extract-receipt` responds (even error = endpoint is reachable)
3. **Round-trip OCR** — Send `test/fixtures/sample_receipt.png` as base64, verify items extracted

Outputs PASS/FAIL/SKIP for each. Non-zero exit on failure.

### Step 7: CI job in .github/workflows/ci.yml
New `test-integration` job that:
- Runs after `test-elixir` passes (`needs: [test-elixir]`)
- Sets up: Elixir, Python 3.11, Tesseract OCR (`apt-get install tesseract-ocr`), PostgreSQL
- Installs both Elixir and Python deps
- Starts Python service on port 8099 in background
- Runs `mix test.integration` with `AI_SERVICE_URL=http://localhost:8099`

### Step 8: Re-enable Python CI job
Remove `if: false` from the existing `test-python` job so Python unit tests also run in CI.

## Key Design Decisions

1. **Bypass Oban**: Integration tests call `Ash.update(receipt, :process)` directly rather than going through Oban. This tests the real processing logic (file read → base64 → HTTP → parse → save) without needing to change Oban's `testing: :manual` config.

2. **Port 8099**: Integration tests use a non-default port to avoid conflicts with a dev Python service on 8000.

3. **Shell script for service management**: Rather than programmatic `Port.open` from Elixir (fragile signal handling), the shell script manages the Python lifecycle. Simpler, more reliable, and matches the `dev-ocr.sh` pattern already in the codebase.

4. **Smoke test as Mix task (not ExUnit)**: Must work without DB access, against remote URLs, outside the test environment. A Mix task is the right abstraction.

5. **No PythonServiceManager module**: Managing uvicorn via Erlang ports is fragile. The shell script approach is more robust and already proven by `dev-ocr.sh`.

## Verification

After implementation:
1. `mix test` — 697+ tests pass, 0 failures (integration tests excluded)
2. `./scripts/test-integration.sh` — Starts Python, runs integration tests, all pass
3. `mix smoke_test` — All 3 checks pass against local Python service
4. `mix smoke_test --url http://localhost:8099` — Same against explicit URL
5. Push → CI `test-integration` job passes alongside existing jobs

## Implementation Status

**Status: COMPLETE**

All 8 implementation steps delivered:

| Step | File | Status |
|------|------|--------|
| 1. Tag exclusion | `test/test_helper.exs` | Done — `exclude: [:integration, :smoke]` |
| 2. Mix alias | `mix.exs` | Done — `test.integration` alias + `preferred_envs` |
| 3. IntegrationCase | `test/support/integration_case.ex` | Done — sandbox, ai_client_opts override, helpers |
| 4. Integration tests | `test/integration/receipt_ocr_integration_test.exs` | Done — 5 tests across 4 groups |
| 5. Test script | `scripts/test-integration.sh` | Done — Python lifecycle, health poll, cleanup |
| 6. Smoke test | `lib/mix/tasks/smoke_test.ex` | Done — 3 checks, --url/--verbose flags |
| 7. CI job | `.github/workflows/ci.yml` | Done — `test-integration` job, `test-python` re-enabled |
| 8. Python CI | `.github/workflows/ci.yml` | Done — removed `if: false`, added Tesseract install |

**Verification:** `mix precommit` passes — 697 tests, 0 failures (5 integration tests excluded).
