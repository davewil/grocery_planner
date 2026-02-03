defmodule GroceryPlanner.ShoppingTestHelpers do
  @moduledoc false

  def create_account do
    {:ok, account} =
      GroceryPlanner.Accounts.Account
      |> Ash.Changeset.for_create(:create, %{name: "Test Account #{System.unique_integer()}"})
      |> Ash.create(authorize?: false)

    account
  end

  def create_user(account) do
    {:ok, user} =
      GroceryPlanner.Accounts.User
      |> Ash.Changeset.for_create(:create, %{
        name: "Test User #{System.unique_integer()}",
        email: "user#{System.unique_integer()}@example.com",
        password: "password123456"
      })
      |> Ash.create(authorize?: false)

    {:ok, _membership} =
      GroceryPlanner.Accounts.AccountMembership
      |> Ash.Changeset.for_create(:create, %{
        account_id: account.id,
        user_id: user.id,
        role: :owner
      })
      |> Ash.create(authorize?: false)

    user
  end

  def create_account_and_user do
    account = create_account()
    user = create_user(account)
    {account, user}
  end

  def create_shopping_list(account, _user, attrs \\ %{}) do
    default_attrs = %{name: "Test Shopping List #{System.unique_integer()}"}
    attrs = Map.merge(default_attrs, attrs)

    GroceryPlanner.Shopping.create_shopping_list!(
      account.id,
      attrs,
      authorize?: false,
      tenant: account.id
    )
  end

  def create_shopping_list_item(account, _user, shopping_list, attrs \\ %{}) do
    default_attrs = %{name: "Test Item #{System.unique_integer()}", shopping_list_id: shopping_list.id}
    attrs = Map.merge(default_attrs, attrs)

    GroceryPlanner.Shopping.create_shopping_list_item!(
      account.id,
      attrs,
      authorize?: false,
      tenant: account.id
    )
  end
end
