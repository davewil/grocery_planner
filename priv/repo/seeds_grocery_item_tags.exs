# Grocery Item Tags Seed Data
# Based on USDA MyPlate, grocery industry standards, and culinary categorization

alias GroceryPlanner.Inventory

# This seed file creates a comprehensive taxonomy of grocery item tags
# Tags are account-specific, so this is a reference list that can be imported
# Users would need to create these tags for their own accounts

defmodule GroceryItemTagSeeds do
  @doc """
  Comprehensive grocery item tag taxonomy based on:
  - USDA MyPlate food groups
  - Grocery industry standards (Instacart, etc.)
  - Culinary categorization
  - Nutritional classification
  - Storage and processing types
  """

  # Define the comprehensive tag taxonomy
  # Format: %{name: "Tag Name", color: "#HEX", description: "Description"}

  def tag_taxonomy do
    [
      # === PRIMARY FOOD CATEGORIES (USDA MyPlate Based) ===
      %{name: "Fruit", color: "#EF4444", description: "Fresh, dried, or preserved fruits"},
      %{name: "Vegetable", color: "#10B981", description: "All vegetables including root, leafy, and other"},
      %{name: "Grain", color: "#F59E0B", description: "Wheat, rice, oats, and other grains"},
      %{name: "Protein", color: "#EF4444", description: "Meat, poultry, fish, eggs, nuts, and legumes"},
      %{name: "Dairy", color: "#3B82F6", description: "Milk, cheese, yogurt, and dairy products"},

      # === VEGETABLE SUBCATEGORIES ===
      %{name: "Leafy Green", color: "#059669", description: "Lettuce, spinach, kale, arugula"},
      %{name: "Root Vegetable", color: "#92400E", description: "Carrots, beets, turnips, radishes"},
      %{name: "Cruciferous", color: "#10B981", description: "Broccoli, cauliflower, cabbage, Brussels sprouts"},
      %{name: "Allium", color: "#C084FC", description: "Onions, garlic, leeks, shallots"},
      %{name: "Nightshade", color: "#DC2626", description: "Tomatoes, peppers, eggplant, potatoes"},
      %{name: "Squash", color: "#F97316", description: "Pumpkin, zucchini, butternut squash"},

      # === FRUIT SUBCATEGORIES ===
      %{name: "Citrus", color: "#FBBF24", description: "Oranges, lemons, limes, grapefruit"},
      %{name: "Berry", color: "#7C3AED", description: "Strawberries, blueberries, raspberries"},
      %{name: "Stone Fruit", color: "#FB923C", description: "Peaches, plums, cherries, apricots"},
      %{name: "Tropical", color: "#FBBF24", description: "Mango, pineapple, papaya, banana"},
      %{name: "Melon", color: "#86EFAC", description: "Watermelon, cantaloupe, honeydew"},

      # === PROTEIN SUBCATEGORIES ===
      %{name: "Poultry", color: "#FB923C", description: "Chicken, turkey, duck"},
      %{name: "Red Meat", color: "#DC2626", description: "Beef, pork, lamb"},
      %{name: "Seafood", color: "#06B6D4", description: "Fish, shellfish, mollusks"},
      %{name: "Pulse", color: "#65A30D", description: "Beans, lentils, chickpeas, peas"},
      %{name: "Nut", color: "#78350F", description: "Almonds, walnuts, cashews, peanuts"},
      %{name: "Seed", color: "#854D0E", description: "Chia, flax, sunflower, pumpkin seeds"},

      # === GRAIN SUBCATEGORIES ===
      %{name: "Whole Grain", color: "#B45309", description: "Whole wheat, brown rice, quinoa, oats"},
      %{name: "Refined Grain", color: "#FDE68A", description: "White rice, white bread, pasta"},
      %{name: "Cereal", color: "#F59E0B", description: "Breakfast cereals, granola, muesli"},

      # === HERBS & AROMATICS ===
      %{name: "Herb", color: "#16A34A", description: "Fresh or dried culinary herbs"},
      %{name: "Spice", color: "#DC2626", description: "Dried spices and spice blends"},
      %{name: "Aromatic", color: "#8B5CF6", description: "Ginger, lemongrass, garlic, aromatics"},

      # === NUTRITIONAL CATEGORIES ===
      %{name: "Carbohydrate", color: "#F59E0B", description: "Primary source of carbohydrates"},
      %{name: "Fat", color: "#FBBF24", description: "Oils, butter, high-fat foods"},
      %{name: "Fiber", color: "#65A30D", description: "High fiber content foods"},

      # === STORAGE & PROCESSING TYPES ===
      %{name: "Fresh", color: "#10B981", description: "Fresh, unprocessed items"},
      %{name: "Frozen", color: "#60A5FA", description: "Frozen foods and ingredients"},
      %{name: "Canned", color: "#94A3B8", description: "Canned and jarred goods"},
      %{name: "Dried", color: "#92400E", description: "Dehydrated or dried items"},
      %{name: "Preserved", color: "#A855F7", description: "Pickled, fermented, or preserved"},

      # === CULINARY USES ===
      %{name: "Staple", color: "#6B7280", description: "Essential pantry staples"},
      %{name: "Condiment", color: "#EF4444", description: "Sauces, dressings, spreads"},
      %{name: "Baking", color: "#F472B6", description: "Baking ingredients and supplies"},
      %{name: "Snack", color: "#FB923C", description: "Snack foods and treats"},
      %{name: "Beverage", color: "#3B82F6", description: "Drinks and beverage ingredients"},

      # === DIETARY CONSIDERATIONS ===
      %{name: "Vegan", color: "#22C55E", description: "No animal products"},
      %{name: "Vegetarian", color: "#84CC16", description: "No meat or fish"},
      %{name: "Gluten-Free", color: "#F59E0B", description: "Contains no gluten"},
      %{name: "Organic", color: "#16A34A", description: "Certified organic"},
      %{name: "Low-Carb", color: "#3B82F6", description: "Low in carbohydrates"},

      # === SPECIALTY CATEGORIES ===
      %{name: "Fermented", color: "#A855F7", description: "Fermented foods (yogurt, kimchi, etc.)"},
      %{name: "Sweetener", color: "#F472B6", description: "Sugar, honey, syrup, artificial sweeteners"},
      %{name: "Sauce", color: "#DC2626", description: "Cooking sauces and bases"},
      %{name: "Oil", color: "#FBBF24", description: "Cooking oils and fats"},
      %{name: "Vinegar", color: "#EC4899", description: "Vinegars and acidic condiments"},
      %{name: "Pasta", color: "#FBBF24", description: "Pasta and noodles"},
      %{name: "Rice", color: "#F5F5F5", description: "All varieties of rice"},
      %{name: "Bread", color: "#D97706", description: "Bread and bread products"},
      %{name: "Cheese", color: "#FBBF24", description: "All cheese varieties"},
      %{name: "Egg", color: "#FEF3C7", description: "Eggs and egg products"},
    ]
  end

  def create_tags_for_account(account_id) do
    IO.puts("\nCreating grocery item tags for account #{account_id}...")

    Enum.each(tag_taxonomy(), fn tag_data ->
      case Inventory.create_grocery_item_tag(account_id, tag_data) do
        {:ok, tag} ->
          IO.puts("  ✓ Created tag: #{tag.name}")
        {:error, error} ->
          IO.puts("  ✗ Failed to create tag #{tag_data.name}: #{inspect(error)}")
      end
    end)

    IO.puts("\nTag creation complete!")
  end

  def print_taxonomy do
    IO.puts("\n=== Grocery Item Tag Taxonomy ===\n")

    groups = [
      {"Primary Food Categories", 0..4},
      {"Vegetable Subcategories", 5..10},
      {"Fruit Subcategories", 11..15},
      {"Protein Subcategories", 16..21},
      {"Grain Subcategories", 22..24},
      {"Herbs & Aromatics", 25..27},
      {"Nutritional Categories", 28..30},
      {"Storage & Processing", 31..35},
      {"Culinary Uses", 36..40},
      {"Dietary Considerations", 41..45},
      {"Specialty Categories", 46..56},
    ]

    tags = tag_taxonomy()

    Enum.each(groups, fn {group_name, range} ->
      IO.puts("\n#{group_name}:")
      Enum.slice(tags, range)
      |> Enum.each(fn tag ->
        IO.puts("  • #{tag.name} - #{tag.description}")
      end)
    end)
  end
end

# Print the taxonomy for reference
GroceryItemTagSeeds.print_taxonomy()

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("To create these tags for a specific account, run:")
IO.puts("  GroceryItemTagSeeds.create_tags_for_account(account_id)")
IO.puts(String.duplicate("=", 80) <> "\n")
