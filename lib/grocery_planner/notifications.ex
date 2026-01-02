defmodule GroceryPlanner.Notifications do
  @moduledoc false
  use Ash.Domain,
    extensions: [AshJsonApi.Domain]

  json_api do
    prefix "/api/json"
  end

  resources do
    resource GroceryPlanner.Notifications.NotificationPreference do
      define :create_notification_preference, action: :create, args: [:user_id, :account_id]
      define :list_notification_preferences, action: :read
      define :get_notification_preference, action: :read, get_by: [:id]
      define :update_notification_preference, action: :update
      define :destroy_notification_preference, action: :destroy
    end
  end
end
