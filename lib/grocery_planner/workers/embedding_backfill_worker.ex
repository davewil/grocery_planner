defmodule GroceryPlanner.Workers.EmbeddingBackfillWorker do
  @moduledoc """
  Oban worker that enqueues embedding generation for all recipes without embeddings.

  ## Usage

      # Backfill all recipes across all accounts
      %{}
      |> GroceryPlanner.Workers.EmbeddingBackfillWorker.new()
      |> Oban.insert()

      # Backfill recipes for a specific account
      %{account_id: account_id}
      |> GroceryPlanner.Workers.EmbeddingBackfillWorker.new()
      |> Oban.insert()
  """
  use Oban.Worker, queue: :ai_jobs, max_attempts: 1

  alias GroceryPlanner.Repo
  alias GroceryPlanner.Workers.EmbeddingWorker

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    account_id = args["account_id"]

    {sql, params} =
      if account_id do
        account_uuid = Ecto.UUID.dump!(account_id)

        {"SELECT id, account_id FROM recipes WHERE embedding IS NULL AND account_id = $1",
         [account_uuid]}
      else
        {"SELECT id, account_id FROM recipes WHERE embedding IS NULL", []}
      end

    case Repo.query(sql, params) do
      {:ok, result} ->
        count = length(result.rows)
        Logger.info("Backfilling embeddings for #{count} recipes")

        Enum.each(result.rows, fn [recipe_id_bin, account_id_bin] ->
          recipe_id = Ecto.UUID.load!(recipe_id_bin)
          acct_id = Ecto.UUID.load!(account_id_bin)

          %{recipe_id: recipe_id, account_id: acct_id}
          |> EmbeddingWorker.new()
          |> Oban.insert()
        end)

        :ok

      {:error, reason} ->
        Logger.error("Backfill query failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
