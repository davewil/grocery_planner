defmodule GroceryPlanner.Repo.Migrations.RemoveLikedPreferences do
  @moduledoc """
  Removes all :liked recipe preference records.

  The preference model is simplified to 2 states:
  - No record = assumed liking (default)
  - :disliked record = active dislike

  Existing :liked records represent the default state and are no longer needed.
  """
  use Ecto.Migration

  def up do
    execute("DELETE FROM recipe_preferences WHERE preference = 'liked'")
  end

  def down do
    # No rollback — :liked records represented the default state
    :ok
  end
end
