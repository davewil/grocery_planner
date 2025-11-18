alias GroceryPlanner.Accounts.{Account, User}
alias GroceryPlanner.Recipes.Recipe
alias GroceryPlanner.Inventory.GroceryItem

# Get the test account and user
{:ok, [account | _]} = Ash.read(Account)
{:ok, [user | _]} = Ash.read(User)

# Create a test recipe
recipe = GroceryPlanner.Recipes.create_recipe!(
  account.id,
  %{
    name: "Classic Spaghetti Carbonara",
    description: "A traditional Italian pasta dish with eggs, cheese, and pancetta",
    instructions: """
1. Bring a large pot of salted water to boil and cook spaghetti according to package directions.

2. While pasta cooks, dice the pancetta and cook in a large skillet until crispy.

3. In a bowl, whisk together eggs, grated Parmesan, and black pepper.

4. Drain pasta, reserving 1 cup of pasta water.

5. Add hot pasta to the skillet with pancetta, remove from heat.

6. Quickly stir in the egg mixture, adding pasta water as needed to create a creamy sauce.

7. Serve immediately with extra Parmesan and black pepper.
    """,
    prep_time_minutes: 10,
    cook_time_minutes: 20,
    servings: 4,
    difficulty: :medium,
    is_favorite: true
  },
  authorize?: false,
  tenant: account.id
)

IO.puts("✓ Created recipe: #{recipe.name}")

# Create more recipes
recipes = [
  %{
    name: "Quick Chicken Stir Fry",
    description: "Fast and healthy weeknight dinner",
    instructions: "1. Cut chicken into strips.\n2. Heat oil in wok.\n3. Stir fry chicken and vegetables.\n4. Add sauce and serve over rice.",
    prep_time_minutes: 15,
    cook_time_minutes: 10,
    servings: 3,
    difficulty: :easy,
    is_favorite: false
  },
  %{
    name: "Beef Wellington",
    description: "An elegant dish for special occasions",
    instructions: "1. Sear beef tenderloin.\n2. Prepare mushroom duxelles.\n3. Wrap in puff pastry.\n4. Bake until golden and cooked to desired doneness.",
    prep_time_minutes: 45,
    cook_time_minutes: 40,
    servings: 6,
    difficulty: :hard,
    is_favorite: false
  }
]

Enum.each(recipes, fn recipe_data ->
  recipe = GroceryPlanner.Recipes.create_recipe!(
    account.id,
    recipe_data,
    authorize?: false,
    tenant: account.id
  )
  IO.puts("✓ Created recipe: #{recipe.name}")
end)

IO.puts("\n✓ Recipe seeding complete!")
