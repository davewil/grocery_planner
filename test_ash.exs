alias GroceryPlanner.Recipes
alias GroceryPlanner.Accounts.User

account_id = Ash.UUID.generate()
user_id = Ash.UUID.generate()
non_existent_id = Ash.UUID.generate()

actor = %User{id: user_id}

try do
  result =
    Recipes.get_recipe(non_existent_id,
      actor: actor,
      tenant: account_id,
      not_found_error?: false
    )

  IO.inspect(result, label: "Result")
rescue
  e -> IO.inspect(e, label: "Raised")
end
