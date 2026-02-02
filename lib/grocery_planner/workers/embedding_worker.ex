defmodule GroceryPlanner.Workers.EmbeddingWorker do
  @moduledoc """
  Oban worker that generates an embedding for a single recipe.

  ## Usage

      %{recipe_id: id, account_id: aid}
      |> GroceryPlanner.Workers.EmbeddingWorker.new()
      |> Oban.insert()
  """
  use Oban.Worker, queue: :ai_jobs, max_attempts: 3

  alias GroceryPlanner.AI.Embeddings
  alias GroceryPlanner.Repo

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"recipe_id" => recipe_id, "account_id" => account_id}}) do
    account_uuid = Ecto.UUID.dump!(account_id)
    recipe_uuid = Ecto.UUID.dump!(recipe_id)

    case Repo.query(
           """
           SELECT id, name, description, instructions, cuisine, difficulty,
                  prep_time_minutes, cook_time_minutes, dietary_needs
           FROM recipes
           WHERE id = $1 AND account_id = $2
           """,
           [recipe_uuid, account_uuid]
         ) do
      {:ok,
       %{
         rows: [
           [_id, name, description, instructions, cuisine, difficulty, prep, cook, dietary] | _
         ]
       }} ->
        recipe = %{
          name: name,
          description: description,
          instructions: instructions,
          cuisine: cuisine,
          difficulty: if(difficulty, do: to_string(difficulty), else: nil),
          dietary_needs: dietary || [],
          prep_time_minutes: prep,
          cook_time_minutes: cook,
          recipe_ingredients: []
        }

        text = Embeddings.build_recipe_text(recipe)

        case Embeddings.generate(text, tenant_id: account_id) do
          {:ok, vector} ->
            Embeddings.update_recipe_embedding(recipe_id, vector)
            Logger.info("Generated embedding for recipe #{recipe_id}")
            :ok

          {:error, reason} ->
            Logger.warning(
              "Failed to generate embedding for recipe #{recipe_id}: #{inspect(reason)}"
            )

            {:error, reason}
        end

      {:ok, %{rows: []}} ->
        Logger.warning("Recipe #{recipe_id} not found in account #{account_id}")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
