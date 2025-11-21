require Ash.Query

alias GroceryPlanner.Accounts.{Account, User, AccountMembership}
alias GroceryPlanner.Recipes.Recipe

IO.puts("Creating test data for voting feature...")

{:ok, account} =
  Account
  |> Ash.Changeset.for_create(:create, %{name: "Voting Test Household"})
  |> Ash.create()

IO.puts("✓ Created account: #{account.name}")

{:ok, user} =
  User
  |> Ash.Changeset.for_create(:create, %{
    email: "voter@test.com",
    name: "Test Voter",
    password: "password123"
  })
  |> Ash.create()

IO.puts("✓ Created user: #{user.email}")

{:ok, _membership} =
  AccountMembership
  |> Ash.Changeset.new()
  |> Ash.Changeset.set_argument(:account_id, account.id)
  |> Ash.Changeset.set_argument(:user_id, user.id)
  |> Ash.Changeset.for_create(:create, %{role: :admin})
  |> Ash.create()

IO.puts("✓ Created membership")

recipes = [
  %{name: "Spaghetti Carbonara", is_favorite: true},
  %{name: "Chicken Tikka Masala", is_favorite: true},
  %{name: "Beef Tacos", is_favorite: true},
  %{name: "Pad Thai", is_favorite: true},
  %{name: "Margherita Pizza", is_favorite: true},
  %{name: "Greek Salad", is_favorite: false}
]

Enum.each(recipes, fn recipe_data ->
  {:ok, recipe} =
    Recipe
    |> Ash.Changeset.for_create(:create, Map.put(recipe_data, :account_id, account.id))
    |> Ash.create(actor: user, tenant: account.id)

  IO.puts("✓ Created recipe: #{recipe.name} (favorite: #{recipe.is_favorite})")
end)

IO.puts("\n✓ Voting test data created successfully!")
IO.puts("  Email: voter@test.com")
IO.puts("  Password: password123")
IO.puts("  Account: #{account.name}")
