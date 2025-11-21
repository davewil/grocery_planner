defmodule GroceryPlanner.Repo.Migrations.AddMealPlanVoting do
  use Ecto.Migration

  def change do
    create table(:meal_plan_vote_sessions, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :starts_at, :utc_datetime, null: false
      add :ends_at, :utc_datetime, null: false
      add :status, :text, null: false, default: "open"
      add :processed_at, :utc_datetime
      add :winning_recipe_ids, {:array, :uuid}

      add :account_id,
          references(:accounts,
            column: :id,
            type: :uuid,
            on_delete: :delete_all
          ),
          null: false

      add :created_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:meal_plan_vote_sessions, [:account_id])
    create index(:meal_plan_vote_sessions, [:status])

    create table(:meal_plan_vote_entries, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :account_id, :uuid, null: false
      add :vote_session_id, :uuid, null: false
      add :recipe_id, :uuid, null: false
      add :user_id, :uuid, null: false
      add :created_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:meal_plan_vote_entries, [:account_id])
    create index(:meal_plan_vote_entries, [:vote_session_id])
    create index(:meal_plan_vote_entries, [:recipe_id])
    create index(:meal_plan_vote_entries, [:user_id])

    create unique_index(:meal_plan_vote_entries, [:account_id, :vote_session_id, :recipe_id, :user_id], name: :unique_vote_per_user_session_recipe)
  end
end