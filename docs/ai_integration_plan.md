# AI Integration Plan for GroceryPlanner

This document outlines a plan to integrate AI and Machine Learning capabilities into the GroceryPlanner application using a **Python Side-car Microservice** architecture.

## Objectives

1.  Enhance user experience by reducing manual data entry (OCR, Categorization).
2.  Provide intelligent recommendations for meal planning and shopping.
3.  Leverage the extensive Python AI/ML ecosystem (Transformers, Z3, PyTorch) while keeping the core Elixir application stable.

## Architecture

*   **Core Application**: Elixir/Phoenix (GroceryPlanner) - Handles UI, business logic, persistence, and auth.
*   **AI Service**: Python (FastAPI/Flask) - Handles inference, optimization, and complex data processing.
*   **Communication**: Synchronous HTTP (REST/JSON) for real-time requests, or Asynchronous (Jobs/Queue) for heavy tasks.

## Status of Previous Elixir Native Spike

A development spike was previously conducted to test `Nx`/`Bumblebee` (Elixir Native ML).
**Status**: Deprecated/Paused.
**Reasoning**: While promising, the Python ecosystem offers a wider range of mature tools (especially for Z3 SMT solving and advanced OCR) and allows for better separation of resource-intensive AI workloads from the core application.

---

## Feature 1: Smart Item Categorization

**Problem**: When creating a new grocery item, users must manually select a category.

**Solution**: Automatically predict the category based on the item name using Zero-Shot Text Classification in the Python service.

### Implementation Strategy

1.  **Model**: Hugging Face Zero-Shot (e.g., `facebook/bart-large-mnli` or similar) running in Python.
2.  **Workflow**:
    *   Elixir sends item name + candidate labels to Python service.
    *   Python runs inference and returns the best label.
    *   Elixir populates the form field.

---

## Feature 2: Semantic Recipe Search

**Problem**: Exact string matching fails to find relevant recipes.

**Solution**: Use Text Embeddings (e.g., `pgvector`) to allow for semantic search.

### Implementation Strategy

1.  **Model**: Sentence Transformers (e.g., `all-MiniLM-L6-v2`) in Python.
2.  **Workflow**:
    *   **Indexing**: On Recipe save, Elixir sends text to Python -> Python returns Vector -> Elixir saves to `pgvector` column.
    *   **Search**: User query -> Python (Vector) -> Elixir (Cosine Similarity Query).

---

## Feature 3: Receipt Scanning & Parsing

**Problem**: Adding items from a shopping trip one by one is time-consuming.

**Solution**: Upload photo -> OCR -> Structured Data.

### Implementation Strategy

1.  **Model**: OCR / LayoutLM / Azure Form Recognizer / Tesseract (managed by Python service).
2.  **Workflow**:
    *   User uploads image to Elixir.
    *   Elixir passes image (or URL) to Python.
    *   Python extracts text/items and returns JSON.
    *   Elixir presents "Review" UI.

---

## Feature 4: Meal Planning Optimization (SMT)

**Problem**: "What do I cook with X, Y, Z that expires soon?"

**Solution**: Satisfiability Modulo Theories (SMT) Solver (Z3).

### Implementation Strategy

1.  **Engine**: Z3 Solver (via `z3-solver` Python package).
2.  **Workflow**:
    *   Elixir constructs problem state (Available Ingredients, Recipes, Constraints) -> JSON.
    *   Python builds Z3 model, solves, and returns list of Recipe IDs.
    *   Elixir renders the suggestion.

---

## Development Plan

See `docs/ai_backlog.md` for the detailed Epics and Stories.