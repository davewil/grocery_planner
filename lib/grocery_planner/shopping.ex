defmodule GroceryPlanner.Shopping do
  use Ash.Domain

  resources do
    resource GroceryPlanner.Shopping.ShoppingList
    resource GroceryPlanner.Shopping.ShoppingListItem
  end
end
