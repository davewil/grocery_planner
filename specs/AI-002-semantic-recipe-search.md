# AI-002: Semantic Recipe Search

## Overview

**Feature:** Vector-based semantic search for recipes using text embeddings and pgvector
**Priority:** High
**Epic:** EMB-01 (Embeddings + Semantic Search)
**Estimated Effort:** 5-7 days

## Problem Statement

Current recipe search relies on exact string matching, which fails to find relevant recipes when users search using different terminology, synonyms, or natural language queries.

**Current Limitations:**
- "Quick dinner" doesn't find "30-minute meals"
- "Italian food" doesn't find "pasta carbonara" unless tagged
- "Something with chicken" requires exact ingredient matching
- "Healthy lunch ideas" returns nothing without explicit tags

## User Stories

### US-001: Natural language recipe search
**As a** user searching for recipes
**I want** to search using natural language queries
**So that** I find relevant recipes even without exact keyword matches

**Acceptance Criteria:**
- [ ] Search accepts free-form text queries
- [ ] Results ranked by semantic relevance
- [ ] "Quick weeknight dinner" finds fast, simple recipes
- [ ] "Something spicy with chicken" finds relevant matches
- [ ] Search completes in < 500ms

### US-002: Hybrid search (keyword + semantic)
**As a** user with specific requirements
**I want** search to combine exact matches with semantic matches
**So that** I get both precise and discovery-based results

**Acceptance Criteria:**
- [ ] Exact recipe name matches ranked highest
- [ ] Semantic matches follow exact matches
- [ ] Configurable weighting between keyword and semantic
- [ ] Filter by difficulty, time, favorites still works

### US-003: Similar recipe discovery
**As a** user viewing a recipe
**I want** to see similar recipes
**So that** I can discover alternatives or variations

**Acceptance Criteria:**
- [ ] "Similar recipes" section on recipe detail page
- [ ] Shows 3-5 most similar recipes
- [ ] Similarity based on ingredients, cuisine, style
- [ ] Excludes the current recipe from results

### US-004: Ingredient-based semantic matching
**As a** user entering ingredients
**I want** fuzzy matching for ingredient names
**So that** "coke" matches "Coca-Cola" and "cilantro" matches "coriander"

**Acceptance Criteria:**
- [ ] Ingredient synonyms supported
- [ ] User corrections feed into synonym database
- [ ] Works for receipt OCR item matching
- [ ] Works for recipe ingredient matching

## Technical Specification

### Architecture

```
┌─────────────────┐                    ┌──────────────────┐
│  Elixir/Phoenix │                    │  Python/FastAPI  │
│   (LiveView)    │                    │   (AI Service)   │
└────────┬────────┘                    └────────┬─────────┘
         │                                      │
         │  1. Generate embedding               │
         │ ────────────────────────────────────►│
         │                                      │
         │  2. Return vector [384 dims]         │
         │ ◄────────────────────────────────────│
         │                                      │
         ▼                                      │
┌─────────────────┐                             │
│   PostgreSQL    │                             │
│   + pgvector    │                             │
│                 │                             │
│  recipes.embedding (vector(384))              │
│  grocery_items.embedding (vector(384))        │
└─────────────────┘
```

### Database Schema Changes

**Migration:** Add vector columns and indexes

```elixir
defmodule GroceryPlanner.Repo.Migrations.AddEmbeddingsSupport do
  use Ecto.Migration

  def up do
    # Enable pgvector extension
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    # Add embedding column to recipes
    alter table(:recipes) do
      add :embedding, :vector, size: 384
      add :embedding_model, :string
      add :embedding_updated_at, :utc_datetime
    end

    # Add embedding column to grocery_items
    alter table(:grocery_items) do
      add :embedding, :vector, size: 384
      add :synonyms, {:array, :string}, default: []
    end

    # Create HNSW index for fast similarity search
    # HNSW is better for high recall, IVFFlat is faster for very large datasets
    execute """
    CREATE INDEX recipes_embedding_idx ON recipes
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64)
    """

    execute """
    CREATE INDEX grocery_items_embedding_idx ON grocery_items
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64)
    """
  end

  def down do
    drop index(:recipes, [:embedding])
    drop index(:grocery_items, [:embedding])

    alter table(:recipes) do
      remove :embedding
      remove :embedding_model
      remove :embedding_updated_at
    end

    alter table(:grocery_items) do
      remove :embedding
      remove :synonyms
    end

    execute "DROP EXTENSION IF EXISTS vector"
  end
end
```

### Python Service Endpoints

#### Generate Embedding

**Endpoint:** `POST /api/v1/embed`

**Request:**
```json
{
  "version": "1.0",
  "request_id": "uuid",
  "texts": [
    {
      "id": "recipe-123",
      "text": "Creamy Tuscan Chicken. A rich Italian-inspired dish with sun-dried tomatoes, spinach, and parmesan in a creamy garlic sauce. Perfect for weeknight dinners."
    }
  ]
}
```

**Response:**
```json
{
  "version": "1.0",
  "request_id": "uuid",
  "model": "all-MiniLM-L6-v2",
  "dimension": 384,
  "embeddings": [
    {
      "id": "recipe-123",
      "vector": [0.023, -0.045, 0.067, ...]
    }
  ]
}
```

#### Batch Embedding (for indexing jobs)

**Endpoint:** `POST /api/v1/embed/batch`

**Request:**
```json
{
  "version": "1.0",
  "request_id": "uuid",
  "texts": [
    {"id": "1", "text": "..."},
    {"id": "2", "text": "..."}
  ],
  "batch_size": 32
}
```

### Model Selection

**Primary Model:** `sentence-transformers/all-MiniLM-L6-v2`
- 384 dimensions (good balance of size/quality)
- Fast inference (~14ms per embedding)
- Good semantic understanding

**Alternative Models:**
| Model | Dimensions | Speed | Quality |
|-------|------------|-------|---------|
| all-MiniLM-L6-v2 | 384 | Fast | Good |
| all-mpnet-base-v2 | 768 | Medium | Better |
| e5-small-v2 | 384 | Fast | Good |

### Elixir Integration

**Module:** `GroceryPlanner.AI.Embeddings`

```elixir
defmodule GroceryPlanner.AI.Embeddings do
  @moduledoc """
  Client for generating and managing text embeddings.
  """

  alias GroceryPlanner.Repo
  import Ecto.Query
  import Pgvector.Ecto.Query

  @doc """
  Generates an embedding vector for the given text.
  """
  @spec generate(String.t()) :: {:ok, [float()]} | {:error, term()}
  def generate(text)

  @doc """
  Generates embeddings for multiple texts in batch.
  """
  @spec generate_batch([String.t()]) :: {:ok, [[float()]]} | {:error, term()}
  def generate_batch(texts)

  @doc """
  Searches recipes by semantic similarity to query.
  Returns recipes ordered by similarity score.
  """
  @spec search_recipes(String.t(), Keyword.t()) :: [Recipe.t()]
  def search_recipes(query, opts \\ [])

  @doc """
  Finds similar recipes to the given recipe.
  """
  @spec find_similar_recipes(Recipe.t(), integer()) :: [Recipe.t()]
  def find_similar_recipes(recipe, limit \\ 5)
end
```

**Search Implementation:**

```elixir
def search_recipes(query, opts) do
  account_id = Keyword.fetch!(opts, :account_id)
  limit = Keyword.get(opts, :limit, 20)
  min_similarity = Keyword.get(opts, :min_similarity, 0.3)

  with {:ok, query_embedding} <- generate(query) do
    Recipe
    |> where([r], r.account_id == ^account_id)
    |> where([r], not is_nil(r.embedding))
    |> order_by([r], cosine_distance(r.embedding, ^query_embedding))
    |> limit(^limit)
    |> select([r], %{
      recipe: r,
      similarity: 1 - cosine_distance(r.embedding, ^query_embedding)
    })
    |> Repo.all()
    |> Enum.filter(fn %{similarity: sim} -> sim >= min_similarity end)
  end
end
```

### Hybrid Search Strategy

Combine keyword search (PostgreSQL full-text) with semantic search:

```elixir
def hybrid_search(query, opts) do
  account_id = Keyword.fetch!(opts, :account_id)
  keyword_weight = Keyword.get(opts, :keyword_weight, 0.3)
  semantic_weight = Keyword.get(opts, :semantic_weight, 0.7)

  # Get keyword matches
  keyword_results = keyword_search(query, account_id)

  # Get semantic matches
  semantic_results = search_recipes(query, account_id: account_id)

  # Combine and re-rank
  combine_results(keyword_results, semantic_results, keyword_weight, semantic_weight)
end

defp keyword_search(query, account_id) do
  search_term = "%#{query}%"

  Recipe
  |> where([r], r.account_id == ^account_id)
  |> where([r], ilike(r.name, ^search_term) or ilike(r.description, ^search_term))
  |> Repo.all()
end
```

### Embedding Generation Job

**Oban Job:** `GroceryPlanner.Workers.EmbeddingWorker`

```elixir
defmodule GroceryPlanner.Workers.EmbeddingWorker do
  use Oban.Worker, queue: :ai_jobs, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "recipe", "id" => recipe_id}}) do
    recipe = Recipes.get_recipe!(recipe_id)
    text = build_recipe_text(recipe)

    with {:ok, embedding} <- AI.Embeddings.generate(text) do
      recipe
      |> Ash.Changeset.for_update(:update_embedding, %{
        embedding: embedding,
        embedding_model: "all-MiniLM-L6-v2",
        embedding_updated_at: DateTime.utc_now()
      })
      |> Ash.update!()

      :ok
    end
  end

  defp build_recipe_text(recipe) do
    """
    #{recipe.name}.
    #{recipe.description || ""}
    Ingredients: #{format_ingredients(recipe.recipe_ingredients)}
    #{recipe.instructions || ""}
    """
  end
end
```

### Recipe Text Construction

For optimal embedding quality, combine recipe attributes:

```elixir
def build_searchable_text(recipe) do
  ingredients = recipe.recipe_ingredients
    |> Enum.map(& &1.grocery_item.name)
    |> Enum.join(", ")

  tags = recipe.tags
    |> Enum.map(& &1.name)
    |> Enum.join(", ")

  [
    recipe.name,
    recipe.description,
    "Ingredients: #{ingredients}",
    "Tags: #{tags}",
    "Difficulty: #{recipe.difficulty}",
    "Time: #{recipe.total_time_minutes} minutes"
  ]
  |> Enum.reject(&is_nil/1)
  |> Enum.join(". ")
end
```

## UI/UX Specifications

### Search Interface

**Enhanced Search Bar:**
```heex
<div class="relative">
  <input
    type="text"
    name="search"
    value={@search_query}
    placeholder="Search recipes... try 'quick Italian dinner' or 'healthy lunch'"
    class="input input-bordered w-full pr-10"
    phx-debounce="300"
    phx-change="search"
  />
  <div class="absolute right-3 top-1/2 -translate-y-1/2">
    <%= if @searching do %>
      <span class="loading loading-spinner loading-sm"></span>
    <% else %>
      <.icon name="hero-magnifying-glass" class="w-5 h-5 text-base-content/50" />
    <% end %>
  </div>
</div>
```

**Search Results:**
- Show relevance indicator (match score as subtle percentage)
- Highlight why recipe matched (matched terms)
- "Similar to your search" section for semantic matches

### Similar Recipes Section

On recipe detail page:
```heex
<.section title="Similar Recipes">
  <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
    <%= for similar <- @similar_recipes do %>
      <.item_card
        title={similar.recipe.name}
        image_url={similar.recipe.image_url}
        description={"#{trunc(similar.similarity * 100)}% similar"}
        clickable
        phx-click="view_recipe"
        phx-value-id={similar.recipe.id}
      />
    <% end %>
  </div>
</.section>
```

### Loading States

- Search: Spinner in search bar
- Initial load: Skeleton cards
- Similar recipes: "Finding similar recipes..." with skeleton

## Testing Strategy

### Unit Tests

```elixir
defmodule GroceryPlanner.AI.EmbeddingsTest do
  use GroceryPlanner.DataCase

  describe "search_recipes/2" do
    test "returns semantically similar recipes" do
      # Create test recipes
      italian = create_recipe("Pasta Carbonara", "Classic Italian pasta")
      mexican = create_recipe("Tacos", "Mexican street food")

      # Generate embeddings
      index_recipe(italian)
      index_recipe(mexican)

      # Search should find Italian recipe
      results = Embeddings.search_recipes("Italian dinner", account_id: account.id)
      assert hd(results).recipe.id == italian.id
    end
  end
end
```

### Semantic Search Golden Tests

| Query | Expected Top Result | Min Similarity |
|-------|---------------------|----------------|
| "quick Italian dinner" | Pasta Carbonara | 0.5 |
| "healthy chicken meal" | Grilled Chicken Salad | 0.5 |
| "comfort food" | Mac and Cheese | 0.4 |
| "spicy Asian" | Thai Red Curry | 0.5 |
| "vegetarian protein" | Lentil Soup | 0.4 |

### Performance Tests

```elixir
test "search completes within 500ms for 1000 recipes" do
  # Create 1000 recipes with embeddings
  create_recipes_with_embeddings(1000)

  {time_us, _results} = :timer.tc(fn ->
    Embeddings.search_recipes("dinner ideas", account_id: account.id)
  end)

  assert time_us < 500_000  # 500ms in microseconds
end
```

## Dependencies

### Python Service
- `sentence-transformers>=2.2.0`
- `torch>=2.0.0`
- `numpy>=1.24.0`

### Elixir App
- `pgvector` - Ecto integration for pgvector
- `oban` - Background job processing (already installed)

### PostgreSQL
- `pgvector` extension (v0.5.0+)

## Configuration

### Environment Variables

```bash
# Elixir
AI_SERVICE_URL=http://grocery-planner-ai.internal:8000
EMBEDDING_MODEL=all-MiniLM-L6-v2
EMBEDDING_DIMENSION=384
SEMANTIC_SEARCH_ENABLED=true

# Python
EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2
MODEL_CACHE_DIR=/app/models
EMBEDDING_BATCH_SIZE=32
```

### Feature Flags

```elixir
config :grocery_planner, :features,
  semantic_search: System.get_env("SEMANTIC_SEARCH_ENABLED", "false") == "true",
  similar_recipes: System.get_env("SIMILAR_RECIPES_ENABLED", "false") == "true"
```

## Rollout Plan

1. **Phase 1:** Enable pgvector extension in production database
2. **Phase 2:** Deploy embedding generation endpoint
3. **Phase 3:** Run backfill job for existing recipes
4. **Phase 4:** Enable semantic search (behind feature flag)
5. **Phase 5:** Add similar recipes section
6. **Phase 6:** Enable hybrid search as default

## Backfill Strategy

For existing recipes without embeddings:

```elixir
defmodule GroceryPlanner.Workers.EmbeddingBackfillWorker do
  use Oban.Worker, queue: :ai_jobs

  def perform(_job) do
    Recipe
    |> where([r], is_nil(r.embedding))
    |> Repo.all()
    |> Enum.each(fn recipe ->
      %{type: "recipe", id: recipe.id}
      |> EmbeddingWorker.new()
      |> Oban.insert()
    end)

    :ok
  end
end
```

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Search result relevance | > 80% satisfaction | User feedback/clicks |
| Query-to-recipe conversion | +20% vs keyword | A/B test |
| Search latency (p95) | < 500ms | Application metrics |
| Embedding coverage | 100% recipes | Database query |

## Open Questions

1. Should embeddings be tenant-isolated or shared across accounts?
2. How often should embeddings be refreshed when recipes are updated?
3. Should we support multiple embedding models for A/B testing?
4. How do we handle recipes with very short descriptions?

## Implementation Status

### Phase 1: Core Semantic Search (COMPLETE)

Implemented in commit `e3f3070`. The following components are working:

- **pgvector extension** enabled in PostgreSQL with HNSW indexes on `recipes` and `grocery_items`
- **`GroceryPlanner.AI.Embeddings`** module with `generate/2`, `generate_batch/2`, `search_recipes/2`, `hybrid_search/2`, `build_recipe_text/1`
- **Python FastAPI service** at `python_service/` generating embeddings via `sentence-transformers/all-MiniLM-L6-v2` (384 dimensions)
- **`EmbeddingWorker`** and **`EmbeddingBackfillWorker`** Oban jobs for background embedding generation
- **Hybrid search** combining keyword (ILIKE) + semantic (cosine distance) with configurable weights
- **Feature flag** `semantic_search: true/false` controlling availability
- **`AshPostgres.Extensions.Vector`** for pgvector type registration (migrated from `Pgvector.Extensions.Vector`)

**What's working:** All user stories (US-001 through US-004) have basic implementations. Embedding generation, batch processing, recipe search, and hybrid search are functional. Tests pass (473 total, 0 failures).

**What's NOT yet done:**
- Similar recipe discovery UI (US-003 UI portion)
- Search result relevance indicators in UI
- Golden test validation against expected similarity scores
- Performance testing at scale (1000+ recipes)

### Phase 2: AshAI Migration (PENDING)

AshAI (`ash_ai` hex package) provides native vector search integration for Ash resources, which would replace the current hand-rolled implementation with declarative Ash patterns.

**Current approach (Phase 1):**
- Custom `Embeddings` module with raw Ecto/SQL queries for vector operations
- Manual `Pgvector.Ecto.Query` imports for `cosine_distance`
- Plain Oban workers (`EmbeddingWorker`, `EmbeddingBackfillWorker`) — not yet migrated to AshOban
- Custom `build_recipe_text/1` for text construction

**AshAI approach (Phase 2):**
- Declare vector attributes directly on Ash resources with `AshAI` extension
- Vector search as native Ash query operations (no raw SQL)
- Embedding generation integrated into Ash resource lifecycle (e.g., after create/update)
- AshOban triggers for background embedding jobs (replacing plain Oban workers)
- Potential for AshAI's built-in text construction from resource attributes

**Migration tasks:**
1. Add `ash_ai` dependency to `mix.exs`
2. Add `AshAI` extension to Recipe resource with vector search configuration
3. Replace `Embeddings.search_recipes/2` raw SQL with Ash vector search actions
4. Migrate `EmbeddingWorker` and `EmbeddingBackfillWorker` to AshOban triggers
5. Update `hybrid_search/2` to use Ash-native query composition
6. Verify all existing tests still pass after migration

**Reference:** [AshAI Documentation](https://hexdocs.pm/ash_ai/readme.html)

## References

- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [Sentence Transformers](https://www.sbert.net/)
- [Hybrid Search Patterns](https://www.pinecone.io/learn/hybrid-search/)
- [AI Backlog - EMB-01](../docs/ai_backlog.md)
