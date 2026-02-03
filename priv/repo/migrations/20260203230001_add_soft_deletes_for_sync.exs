defmodule GroceryPlanner.Repo.Migrations.AddSoftDeletesForSync do
  use Ecto.Migration

  def change do
    tables = [
      :shopping_list_items,
      :shopping_lists,
      :recipe_ingredients,
      :recipes,
      :inventory_entries,
      :grocery_items,
      :meal_plans,
      :meal_plan_templates,
      :meal_plan_template_entries,
      :meal_plan_vote_sessions,
      :meal_plan_vote_entries
    ]

    for table <- tables do
      alter table(table) do
        add :deleted_at, :utc_datetime_usec, null: true
      end

      create index(table, [:deleted_at])
      create index(table, [:updated_at])
    end
  end
end
