ExUnit.start(exclude: [:integration, :smoke])
Ecto.Adapters.SQL.Sandbox.mode(GroceryPlanner.Repo, :manual)
