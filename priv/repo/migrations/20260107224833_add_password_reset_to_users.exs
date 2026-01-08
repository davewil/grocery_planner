defmodule GroceryPlanner.Repo.Migrations.AddPasswordResetToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :reset_password_token, :string
      add :reset_password_sent_at, :utc_datetime
    end

    create index(:users, [:reset_password_token], unique: true)
  end
end
