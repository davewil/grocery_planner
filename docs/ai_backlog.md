# AI Roadmap Backlog (Epics → Stories → Acceptance Criteria)

_Last updated: 2025-12-29_

This backlog is written to fit the existing architecture:
- Phoenix + LiveView + Ash as system-of-record (multi-tenant)
- Existing JSON:API + OpenAPI surface (see `docs/API.md`)
- AI features implemented via a Python service for maximum ecosystem leverage

## Milestones
- **M1 (Days 0–30)**: AI platform skeleton + Receipt ingestion v1 + Chat assistant v1
- **M2 (Days 31–60)**: Embeddings + semantic search + Recommendations v1
- **M3 (Days 61–90)**: Optimization (SMT/Z3) + Forecasting v1

## Definitions
- **Tenant**: an `account_id` (household). Every AI request/result must be tenant-scoped.
- **AI job**: long-running tasks executed asynchronously (OCR, embedding refresh, forecast runs).
- **AI request**: synchronous inference calls (small/fast tasks).

---

## EPIC AIP-01: AI Platform Foundation (Contracts, Jobs, Storage, Observability)

**Goal**: Provide a stable integration boundary so AI features ship without destabilizing core domains.

### Story AIP-01.01 — Define AI integration contract (request/response)
**As a** developer, **I want** versioned schemas for AI calls, **so that** models/prompts can evolve safely.

**Acceptance criteria**
- A versioned request/response schema exists for: chat, receipt extraction, recommendations, forecasting, optimization.
- Schema includes: `account_id` (tenant), `user_id` (actor), `request_id`, `feature`, `version`, and `metadata`.
- Schema changes require a version bump and remain backward-compatible for at least one previous version.

### Story AIP-01.02 — Add AI job runner (async) with status tracking
**As a** user, **I want** long AI tasks to run in background, **so that** the UI stays responsive.

**Acceptance criteria**
- A background job can be submitted with an id and queried for status (`queued|running|succeeded|failed`).
- Jobs record started/finished timestamps and an error message on failure.
- Jobs are tenant-scoped and only visible to users in the same tenant.

### Story AIP-01.03 — Persist AI artifacts (raw inputs, outputs, and feedback)
**As a** developer, **I want** durable storage of AI inputs/outputs, **so that** we can debug and evaluate.

**Acceptance criteria**
- Each AI request/job stores: sanitized input payload, output payload, latency, model identifier/version, and cost fields (if available).
- User feedback can be stored (thumbs up/down + optional note) and linked to the AI artifact.
- Data retention policy is documented (what is stored and for how long).

### Story AIP-01.04 — Add tracing/logging across Phoenix ↔ Python boundary
**As a** developer, **I want** correlated logs, **so that** production incidents are diagnosable.

**Acceptance criteria**
- `request_id` is propagated end-to-end.
- Structured logs include feature name, tenant id, latency, status.
- A “debug view” exists for admins/developers (or internal only) to inspect last N AI calls.

### Story AIP-01.05 — Add feature flags and kill switch for AI features
**As a** product owner, **I want** to disable an AI feature quickly, **so that** incidents don’t block core app usage.

**Acceptance criteria**
- Each AI feature can be enabled/disabled per environment.
- When disabled, UI provides a graceful fallback (no crashes, meaningful messaging).

### Story AIP-01.06 — Security: enforce tenant scoping and PII minimization
**As a** user, **I want** my household’s data isolated, **so that** AI features don’t leak information.

**Acceptance criteria**
- Every AI call includes tenant context; service rejects missing/invalid tenant context.
- Only the minimum necessary fields are sent to the AI service.
- A documented inventory of PII fields exists for AI payloads.

---

## EPIC RCP-01: Receipt Ingestion (OCR → Extraction → Reconciliation → Inventory)

**Goal**: Turn receipts into inventory entries with human-in-the-loop correction.

### Story RCP-01.01 — Receipt upload UI and storage
**As a** user, **I want** to upload a receipt image/PDF, **so that** the system can extract items.

**Acceptance criteria**
- UI supports image upload (and optionally PDF).
- Receipt is stored and linked to the tenant.
- Upload produces an AI job id and shows progress until completion.

### Story RCP-01.02 — OCR + line-item extraction via Python service
**As a** user, **I want** line items extracted (name, quantity, price), **so that** I don’t type them.

**Acceptance criteria**
- Extraction output includes: merchant (if detectable), purchase date (if detectable), total (optional), and line items.
- Each line item includes a confidence score.
- Failures produce a clear error and allow retry.

### Story RCP-01.03 — Reconciliation UI (human-in-the-loop)
**As a** user, **I want** to review and correct extracted line items, **so that** inventory stays accurate.

**Acceptance criteria**
- User can edit line item name/quantity/unit/price.
- User can delete incorrect line items.
- Corrections are saved as training signals (stored as feedback artifacts).

### Story RCP-01.04 — Match extracted items to existing grocery catalog
**As a** user, **I want** extracted items auto-matched to my catalog, **so that** inventory entries are consistent.

**Acceptance criteria**
- System proposes a `GroceryItem` match per line item with a confidence score.
- User can accept or override the match.
- If no match exists, user can create a new `GroceryItem` during reconciliation.

### Story RCP-01.05 — Create inventory entries from reconciled receipt
**As a** user, **I want** confirmed receipt items to become inventory, **so that** my stock is up to date.

**Acceptance criteria**
- Creates `InventoryEntry` records with quantity/unit, optional purchase price/date.
- Uses a selected storage location default (with ability to change per item).
- All created entries are tenant-scoped and appear in Inventory UI immediately.

### Story RCP-01.06 — Duplicate detection and idempotency
**As a** user, **I want** to avoid double-importing a receipt, **so that** inventory doesn’t inflate.

**Acceptance criteria**
- Re-importing the same receipt (hash-based) warns user and blocks by default.
- Job submission is idempotent using `request_id`.

---

## EPIC AST-01: AI Assistant (Chat) With Tooling

**Goal**: A reliable assistant that uses real app actions (“tools”), not hallucinations.

### Story AST-01.01 — Chat UI and conversation persistence
**As a** user, **I want** a chat interface, **so that** I can ask planning questions naturally.

**Acceptance criteria**
- Conversation is tenant-scoped.
- Messages are persisted with timestamps and the model/version used.
- UI supports streaming or incremental updates (or shows progress state for slower replies).

### Story AST-01.02 — Tool: “What’s expiring soon?”
**As a** user, **I want** the assistant to list expiring items, **so that** I can plan meals to reduce waste.

**Acceptance criteria**
- Assistant can call a backend tool that returns expiring items with days-to-expiry.
- Response cites concrete items (from DB) and does not invent inventory.

### Story AST-01.03 — Tool: “Suggest recipes I can make”
**As a** user, **I want** recipe suggestions grounded in my inventory, **so that** suggestions are actionable.

**Acceptance criteria**
- Assistant can call a tool returning candidate recipes with ingredient availability.
- Response includes missing ingredients (if any) and highlights expiring-item usage.

### Story AST-01.04 — Tool: “Draft a shopping list from meal plan”
**As a** user, **I want** the assistant to draft a shopping list, **so that** I can shop faster.

**Acceptance criteria**
- Assistant can generate a draft list via backend tool (no direct DB writes without confirmation).
- User must confirm before list is finalized.

### Story AST-01.05 — Tool: “Add meal plan entries”
**As a** user, **I want** the assistant to schedule meals, **so that** planning is quick.

**Acceptance criteria**
- Assistant proposes a plan and asks for confirmation.
- On confirmation, it creates meal plan entries and returns a link to view them.

### Story AST-01.06 — Safety: refusal and guardrails
**As a** product owner, **I want** the assistant to be safe and predictable, **so that** it doesn’t take destructive actions.

**Acceptance criteria**
- Assistant never deletes data.
- Assistant never writes inventory/meal plans/shopping lists without explicit confirmation.
- Assistant responses include a brief “what I did” summary when tools were called.

---

## EPIC EMB-01: Embeddings + Semantic Search (pgvector)

**Goal**: Improve discovery and ranking via vector search.

### Story EMB-01.01 — Add embeddings storage and indexing
**As a** developer, **I want** to store embeddings in Postgres, **so that** we can do semantic search.

**Acceptance criteria**
- `pgvector` is installed and migration adds vector columns for recipes (at minimum).
- Vector index exists (HNSW or IVF depending on choice).
- Embeddings are tenant-scoped or logically separated to avoid cross-tenant leakage.

### Story EMB-01.02 — Generate recipe embeddings (batch job)
**As a** developer, **I want** embeddings generated asynchronously, **so that** ingestion doesn’t block UI.

**Acceptance criteria**
- A job generates embeddings for recipes and updates the DB.
- Re-run is idempotent and supports incremental updates.

### Story EMB-01.03 — Semantic recipe search UI
**As a** user, **I want** semantic recipe search, **so that** I can find recipes by intent.

**Acceptance criteria**
- Search returns recipes ranked by semantic similarity.
- Search results still respect existing filters (difficulty, favorites) if applicable.

### Story EMB-01.04 — Hybrid search (keyword + semantic)
**As a** user, **I want** robust search, **so that** exact matches and semantic matches both work.

**Acceptance criteria**
- Supports a hybrid scoring approach (configurable weights).
- Results are stable and testable via deterministic fixtures.

### Story EMB-01.05 — Embed grocery items / synonyms
**As a** user, **I want** better matching from receipts and recipes, **so that** “coke” maps to “Coca‑Cola”.

**Acceptance criteria**
- Grocery items can have synonyms.
- Matching uses embeddings and/or fuzzy matching; user overrides feed back into synonyms.

---

## EPIC REC-01: Recommendations (Recipes, Meals, Shopping)

**Goal**: Ship useful personalized recommendations quickly, starting with explainable heuristics.

### Story REC-01.01 — Explainable recipe ranking baseline
**As a** user, **I want** recommended recipes, **so that** I can decide quickly what to cook.

**Acceptance criteria**
- Recommendations incorporate: ingredient availability, expiring items, favorites, and time-to-cook.
- Each recommendation includes an explanation (e.g., “uses 3 expiring items”).

### Story REC-01.02 — “Optimize my fridge” (non-SMT baseline)
**As a** user, **I want** an “optimize” button that suggests next meals, **so that** I reduce waste.

**Acceptance criteria**
- Produces 3–5 recipe suggestions prioritizing expiring items.
- Requires no solver yet; deterministic heuristic implementation.

### Story REC-01.03 — Capture user interaction signals
**As a** developer, **I want** to log interactions, **so that** we can improve ranking over time.

**Acceptance criteria**
- Logs events: recipe viewed, favorited, scheduled, cooked, skipped.
- Logs are tenant-scoped and include recipe id and timestamp.

### Story REC-01.04 — Personalized re-ranking (ML optional)
**As a** user, **I want** suggestions to adapt to my household, **so that** they improve over time.

**Acceptance criteria**
- Re-ranking uses interaction signals.
- System can fall back to baseline if personalization data is insufficient.

### Story REC-01.05 — Shopping suggestions (“you’ll probably need this soon”)
**As a** user, **I want** proactive shopping suggestions, **so that** I don’t run out of staples.

**Acceptance criteria**
- Suggestions list includes reason (past frequency, forecasted run-out).
- User can dismiss suggestions and dismissal is remembered.

---

## EPIC OPT-01: Meal Planning Optimization (SMT/Z3)

**Goal**: Generate optimized meal sets under constraints (waste minimization, shopping minimization).

### Story OPT-01.01 — Define optimization inputs and constraints
**As a** user, **I want** to specify constraints, **so that** the plan fits my needs.

**Acceptance criteria**
- Constraints supported: expiring threshold, max new items, time budget, avoid repeats, dietary tags.
- Input schema is validated and versioned.

### Story OPT-01.02 — Implement Z3-based solver in Python service
**As a** developer, **I want** to solve optimization using Z3, **so that** results are high quality.

**Acceptance criteria**
- Python service exposes an endpoint to return top N meal plan candidates.
- Response includes the selected recipes and a structured explanation of constraint satisfaction.

### Story OPT-01.03 — Optimization UI entry point (“Waste Watch”)
**As a** user, **I want** a single-click optimization entry point, **so that** I can get value fast.

**Acceptance criteria**
- Inventory/meal planning view shows an optimize action when expiring items exist.
- Optimization runs as a background job and displays results when ready.

### Story OPT-01.04 — Convert optimization result into a meal plan (with confirmation)
**As a** user, **I want** to apply a suggested plan, **so that** it becomes my schedule.

**Acceptance criteria**
- User must confirm before creating meal plan entries.
- Applying the plan creates tenant-scoped meal plan entries.

### Story OPT-01.05 — Generate associated shopping list for missing ingredients
**As a** user, **I want** the missing ingredients turned into a shopping list, **so that** I can execute.

**Acceptance criteria**
- After plan apply, user can create a shopping list from missing ingredients.
- Shopping list groups items and deduplicates overlaps.

---

## EPIC FRC-01: Forecasting (Run-out dates, purchase cadence, anomalies)

**Goal**: Predict near-future needs using consumption/waste and historical usage.

### Story FRC-01.01 — Define forecasting targets and evaluation metrics
**As a** developer, **I want** clear targets, **so that** forecasts are testable.

**Acceptance criteria**
- Targets defined: run-out date estimate, next purchase suggestion date, confidence.
- Baseline metrics defined (MAE on days-to-run-out, coverage for confidence intervals).

### Story FRC-01.02 — Build a forecasting dataset from usage logs
**As a** developer, **I want** a reliable dataset, **so that** models can be trained consistently.

**Acceptance criteria**
- Dataset derivation is deterministic and repeatable.
- Excludes cross-tenant data mixing.

### Story FRC-01.03 — Forecasting job and persistence
**As a** user, **I want** forecasts updated periodically, **so that** suggestions stay current.

**Acceptance criteria**
- Scheduled job produces forecasts for common items.
- Forecasts stored with timestamps and model version.

### Story FRC-01.04 — UI: “Running low soon” and “Buy next week”
**As a** user, **I want** proactive warnings, **so that** I avoid running out.

**Acceptance criteria**
- UI shows top predicted run-outs within a configurable horizon.
- Each suggestion includes a confidence indicator and explanation.

### Story FRC-01.05 — Anomaly detection (optional)
**As a** user, **I want** to detect unusual consumption, **so that** I can correct inventory or spot waste.

**Acceptance criteria**
- Flags outlier usage events above a threshold.
- Provides an action to review and correct associated entries.

---

## EPIC EVAL-01: Evaluation, Prompt/Model Regression Testing, and Cost Control

**Goal**: Prevent AI regressions and keep costs predictable.

### Story EVAL-01.01 — Create golden test sets per feature
**As a** developer, **I want** representative test cases, **so that** we can catch regressions early.

**Acceptance criteria**
- Each feature has a small golden dataset (10–50 cases) stored in-repo or in a controlled dataset store.
- Running the evaluation produces a report with pass/fail thresholds.

### Story EVAL-01.02 — Automated evaluation in CI (smoke)
**As a** developer, **I want** CI checks for AI changes, **so that** merges don’t degrade quality.

**Acceptance criteria**
- CI runs a small evaluation subset on PRs.
- CI run does not require production secrets (uses stubs/mocks for external model calls).

### Story EVAL-01.03 — Cost budgets and rate limiting
**As a** product owner, **I want** spending limits, **so that** costs don’t surprise us.

**Acceptance criteria**
- Per-tenant or per-environment budgets exist.
- Requests above the limit fail gracefully with a helpful UI message.

---

## GitHub Issues Mapping (optional)

If you want, I can auto-create GitHub Issues for:
- Each epic as an Issue with a checklist of its stories
- Each story as a separate Issue (linked to the epic)

Repo detected via `gh`: https://github.com/davewil/grocery_planner
