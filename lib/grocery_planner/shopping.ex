defmodule GroceryPlanner.Shopping do
  use Ash.Domain

  resources do
    resource GroceryPlanner.Shopping.ShoppingList do
      define :create_shopping_list, action: :create, args: [:account_id]
      define :list_shopping_lists, action: :read
      define :get_shopping_list, action: :read, get_by: [:id]
      define :update_shopping_list, action: :update
      define :destroy_shopping_list, action: :destroy
      define :complete_shopping_list, action: :complete
      define :archive_shopping_list, action: :archive
      define :reactivate_shopping_list, action: :reactivate
      define :generate_shopping_list_from_meal_plans, action: :generate_from_meal_plans, args: [:account_id, :start_date, :end_date]
    end

    resource GroceryPlanner.Shopping.ShoppingListItem do
      define :create_shopping_list_item, action: :create, args: [:account_id]
      define :list_shopping_list_items, action: :read
      define :get_shopping_list_item, action: :read, get_by: [:id]
      define :update_shopping_list_item, action: :update
      define :destroy_shopping_list_item, action: :destroy
      define :toggle_shopping_list_item_check, action: :toggle_check
    end
  end
end
