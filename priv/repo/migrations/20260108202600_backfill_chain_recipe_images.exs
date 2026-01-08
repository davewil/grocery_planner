defmodule GroceryPlanner.Repo.Migrations.BackfillChainRecipeImages do
  @moduledoc """
  Data migration to add image_url to existing chain recipes.
  """

  use Ecto.Migration

  def up do
    # Chicken Chain
    execute """
    UPDATE recipes SET image_url = 'https://www.themealdb.com/images/media/meals/qxutws1486978099.jpg'
    WHERE name = 'Sunday Roast Chicken' AND image_url IS NULL
    """

    execute """
    UPDATE recipes SET image_url = 'https://www.themealdb.com/images/media/meals/qqwypw1504642429.jpg'
    WHERE name = 'Chicken & Leek Risotto' AND image_url IS NULL
    """

    execute """
    UPDATE recipes SET image_url = 'https://www.themealdb.com/images/media/meals/sutxtx1487965141.jpg'
    WHERE name = 'Hearty Chicken & Corn Soup' AND image_url IS NULL
    """

    # Green Bag Chain
    execute """
    UPDATE recipes SET image_url = 'https://www.themealdb.com/images/media/meals/1548772327.jpg'
    WHERE name = 'Pan-Seared Salmon with Crispy Kale' AND image_url IS NULL
    """

    execute """
    UPDATE recipes SET image_url = 'https://www.themealdb.com/images/media/meals/ustsqw1468250014.jpg'
    WHERE name = 'Spicy Sausage & Kale Orecchiette' AND image_url IS NULL
    """

    execute """
    UPDATE recipes SET image_url = 'https://www.themealdb.com/images/media/meals/rsutuy1511179166.jpg'
    WHERE name = 'Green Recovery Smoothie' AND image_url IS NULL
    """
  end

  def down do
    # Optional: Clear the images we added
    for name <- [
          "Sunday Roast Chicken",
          "Chicken & Leek Risotto",
          "Hearty Chicken & Corn Soup",
          "Pan-Seared Salmon with Crispy Kale",
          "Spicy Sausage & Kale Orecchiette",
          "Green Recovery Smoothie"
        ] do
      execute "UPDATE recipes SET image_url = NULL WHERE name = '#{name}'"
    end
  end
end
