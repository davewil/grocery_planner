defmodule GroceryPlanner.OnboardingTest do
  use GroceryPlanner.DataCase, async: true
  alias GroceryPlanner.Onboarding
  alias GroceryPlanner.Inventory.GroceryItem
  alias GroceryPlanner.Recipes.Recipe
  alias GroceryPlanner.Accounts.{Account, User, AccountMembership}
  require Ash.Query

  setup do
    {:ok, account} = Account.create(%{name: "Test Account"}, authorize?: false)

    {:ok, user} =
      User.create("test_onboarding@example.com", "Test User", "password1234", authorize?: false)

    {:ok, _membership} =
      AccountMembership.create(account.id, user.id, %{role: :owner}, authorize?: false)

    %{account: account, user: user}
  end

  test "seed_account/2 with omnivore kit seeds chicken chain", %{account: account, user: user} do
    assert :ok = Onboarding.seed_account(account.id, :omnivore)

    # Verify Recipes
    recipes =
      Recipe
      |> Ash.Query.for_read(:read, %{}, actor: user, tenant: account.id)
      |> Ash.read!()

    # Check for the chicken chain
    roast = Enum.find(recipes, &(&1.name == "Sunday Roast Chicken"))
    risotto = Enum.find(recipes, &(&1.name == "Chicken & Leek Risotto"))
    soup = Enum.find(recipes, &(&1.name == "Hearty Chicken & Corn Soup"))

    assert roast.is_base_recipe
    assert risotto.is_follow_up
    assert risotto.parent_recipe_id == roast.id
    assert soup.is_follow_up
    assert soup.parent_recipe_id == roast.id

    # Verify leftover ingredient
    risotto =
      risotto |> Ash.load!([recipe_ingredients: [:grocery_item]], actor: user, tenant: account.id)

    leftover_ing = Enum.find(risotto.recipe_ingredients, &(&1.usage_type == :leftover))
    assert leftover_ing
    assert leftover_ing.grocery_item.name == "Roast Chicken Leftovers"
  end

  test "seed_account/2 with vegan kit excludes meat", %{account: account, user: user} do
    assert :ok = Onboarding.seed_account(account.id, :vegan)

    items =
      GroceryItem
      |> Ash.Query.for_read(:read, %{}, actor: user, tenant: account.id)
      |> Ash.read!()

    item_names = Enum.map(items, & &1.name)

    # "Whole Chicken" should definitely not be there
    refute "Whole Chicken" in item_names

    refute "Sunday Roast Chicken" in (Recipe
                                      |> Ash.read!(actor: user, tenant: account.id)
                                      |> Enum.map(& &1.name))
  end

  test "seed_account/2 with nil kit seeds categories and locations but no recipes or items", %{
    account: account,
    user: user
  } do
    assert :ok = Onboarding.seed_account(account.id, nil)

    # Categories should be seeded
    categories =
      GroceryPlanner.Inventory.Category
      |> Ash.Query.for_read(:read, %{}, actor: user, tenant: account.id)
      |> Ash.read!()

    assert length(categories) > 0

    # Storage locations should be seeded
    locations =
      GroceryPlanner.Inventory.StorageLocation
      |> Ash.Query.for_read(:read, %{}, actor: user, tenant: account.id)
      |> Ash.read!()

    assert length(locations) > 0

    # No recipes should exist
    recipes =
      Recipe
      |> Ash.Query.for_read(:read, %{}, actor: user, tenant: account.id)
      |> Ash.read!()

    assert recipes == []

    # No grocery items should exist
    items =
      GroceryItem
      |> Ash.Query.for_read(:read, %{}, actor: user, tenant: account.id)
      |> Ash.read!()

    assert items == []
  end

  test "seed_account/2 with single_couple kit seeds green bag chain", %{
    account: account,
    user: user
  } do
    assert :ok = Onboarding.seed_account(account.id, :single_couple)

    # Verify Recipes
    recipes =
      Recipe
      |> Ash.Query.for_read(:read, %{}, actor: user, tenant: account.id)
      |> Ash.read!()

    # Check for the green bag chain
    salmon = Enum.find(recipes, &(&1.name == "Pan-Seared Salmon with Crispy Kale"))
    pasta = Enum.find(recipes, &(&1.name == "Spicy Sausage & Kale Orecchiette"))
    smoothie = Enum.find(recipes, &(&1.name == "Green Recovery Smoothie"))

    assert salmon.is_base_recipe
    assert salmon.waste_reduction_tip =~ "1/3 of the kale"

    assert pasta.is_follow_up
    assert pasta.parent_recipe_id == salmon.id
    assert pasta.waste_reduction_tip =~ "Almost done with the kale"

    assert smoothie.is_follow_up
    assert smoothie.parent_recipe_id == salmon.id

    # Verify Kale is marked as waste risk
    kale =
      GroceryItem
      |> Ash.Query.filter(name == "Kale")
      |> Ash.read_one!(actor: user, tenant: account.id)

    assert kale.is_waste_risk
  end
end
