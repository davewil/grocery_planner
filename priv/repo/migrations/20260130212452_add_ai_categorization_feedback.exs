defmodule GroceryPlanner.Repo.Migrations.AddAiCategorizationFeedback do
  use Ecto.Migration

  def up do
    create table(:ai_categorization_feedback, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :account_id, references(:accounts, type: :uuid, on_delete: :delete_all), null: false
      add :item_name, :string, null: false
      add :predicted_category, :string, null: false
      add :predicted_confidence, :float, null: false
      add :user_selected_category, :string, null: false
      add :was_correction, :boolean, default: false
      add :model_version, :string

      timestamps(type: :utc_datetime, inserted_at: :created_at)
    end

    create index(:ai_categorization_feedback, [:account_id])
    create index(:ai_categorization_feedback, [:was_correction])
    create index(:ai_categorization_feedback, [:created_at])
  end

  def down do
    drop table(:ai_categorization_feedback)
  end
end
