defmodule GroceryPlanner.Notifications.NotificationPreferenceTest do
  use GroceryPlanner.DataCase

  alias GroceryPlanner.Notifications.NotificationPreference
  alias GroceryPlanner.InventoryTestHelpers

  describe "notification preferences" do
    setup do
      {account, user} = InventoryTestHelpers.create_account_and_user()
      %{account: account, user: user}
    end

    test "creates preferences with default values", %{account: account, user: user} do
      {:ok, pref} =
        NotificationPreference
        |> Ash.Changeset.for_create(:create, %{
          user_id: user.id,
          account_id: account.id
        })
        |> Ash.create(authorize?: false, tenant: account.id)

      assert pref.expiration_alerts_enabled == true
      assert pref.expiration_alert_days == 7
      assert pref.recipe_suggestions_enabled == true
      assert pref.email_notifications_enabled == false
      assert pref.in_app_notifications_enabled == true
    end

    test "updates preferences successfully", %{account: account, user: user} do
      {:ok, pref} =
        NotificationPreference
        |> Ash.Changeset.for_create(:create, %{
          user_id: user.id,
          account_id: account.id
        })
        |> Ash.create(authorize?: false, tenant: account.id)

      {:ok, updated} =
        pref
        |> Ash.Changeset.for_update(:update, %{
          expiration_alert_days: 3,
          email_notifications_enabled: true
        })
        |> Ash.update(authorize?: false, tenant: account.id)

      assert updated.expiration_alert_days == 3
      assert updated.email_notifications_enabled == true
    end

    test "enforces required relationships", %{account: account} do
      assert {:error, error} =
               NotificationPreference
               |> Ash.Changeset.for_create(:create, %{
                 account_id: account.id
                 # Missing user_id
               })
               |> Ash.create(authorize?: false, tenant: account.id)

      assert %Ash.Error.Invalid{} = error
    end
  end
end
