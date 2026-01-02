defmodule GroceryPlanner.Accounts do
  @moduledoc false
  use Ash.Domain

  resources do
    resource GroceryPlanner.Accounts.User
    resource GroceryPlanner.Accounts.Account
    resource GroceryPlanner.Accounts.AccountMembership
  end
end
