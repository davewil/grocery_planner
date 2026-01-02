defmodule GroceryPlanner.MealPlanningTestHelpers do
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

  def create_recipe(account, user, attrs \\ %{}) do
    default_attrs = %{
      name: "Test Recipe #{System.unique_integer()}",
      description: "A delicious test recipe",
      prep_time_minutes: 15,
      cook_time_minutes: 30,
      servings: 4,
      difficulty: :medium
    }

    attrs = Map.merge(default_attrs, attrs)

    {:ok, recipe} =
      GroceryPlanner.Recipes.Recipe
      |> Ash.Changeset.new()
      |> Ash.Changeset.set_argument(:account_id, account.id)
      |> Ash.Changeset.for_create(:create, attrs)
      |> Ash.create(actor: user, tenant: account.id)

    recipe
  end

  def create_meal_plan(account, user, recipe, attrs \\ %{}) do
    default_attrs = %{
      recipe_id: recipe.id,
      scheduled_date: Date.utc_today(),
      meal_type: :dinner,
      servings: 4
    }

    attrs = Map.merge(default_attrs, attrs)

    {:ok, meal_plan} =
      GroceryPlanner.MealPlanning.MealPlan
      |> Ash.Changeset.new()
      |> Ash.Changeset.set_argument(:account_id, account.id)
      |> Ash.Changeset.for_create(:create, attrs)
      |> Ash.create(actor: user, tenant: account.id)

    meal_plan
  end
end
