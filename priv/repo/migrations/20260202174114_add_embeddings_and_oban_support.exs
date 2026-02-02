defmodule GroceryPlanner.Repo.Migrations.AddEmbeddingsAndObanSupport do
  use Ecto.Migration

  def up do
    # Oban job tables
    Oban.Migration.up(version: 12)

    # Enable pgvector extension
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    # Add embedding columns to recipes
    alter table(:recipes) do
      add :embedding, :vector, size: 384
      add :embedding_model, :string
      add :embedding_updated_at, :utc_datetime
    end

    # Create HNSW index for fast similarity search
    execute """
    CREATE INDEX recipes_embedding_idx ON recipes
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64)
    """
  end

  def down do
    execute "DROP INDEX IF EXISTS recipes_embedding_idx"

    alter table(:recipes) do
      remove :embedding
      remove :embedding_model
      remove :embedding_updated_at
    end

    execute "DROP EXTENSION IF EXISTS vector"

    Oban.Migration.down(version: 1)
  end
end
