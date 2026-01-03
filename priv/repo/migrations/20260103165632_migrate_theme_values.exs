defmodule GroceryPlanner.Repo.Migrations.MigrateThemeValues do
  @moduledoc """
  Migrates existing user theme values to daisyUI preset themes.

  - "progressive" → "cyberpunk" (closest visual match: vibrant, futuristic)
  - "light" → "light" (unchanged)
  - "dark" → "dark" (unchanged)
  - Invalid themes → "light" (fallback)
  """
  use Ecto.Migration

  def up do
    # Map "progressive" theme to "cyberpunk" (closest daisyUI preset match)
    execute """
    UPDATE users
    SET theme = 'cyberpunk'
    WHERE theme = 'progressive'
    """

    # Set any other invalid themes to default "light"
    execute """
    UPDATE users
    SET theme = 'light'
    WHERE theme NOT IN (
      'light', 'dark', 'cupcake', 'bumblebee', 'synthwave', 'retro',
      'cyberpunk', 'dracula', 'nord', 'sunset', 'business', 'luxury'
    )
    """
  end

  def down do
    # Revert cyberpunk back to progressive (for rollback)
    execute """
    UPDATE users
    SET theme = 'progressive'
    WHERE theme = 'cyberpunk'
    """
  end
end
