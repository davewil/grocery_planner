defmodule GroceryPlanner.FamilyTestHelpers do
  @moduledoc """
  Test helpers for the Family domain.

  Account/user creation helpers are inherited from InventoryTestHelpers
  via DataCase. This module only defines family-specific helpers.
  """

  def create_family_member(account, _user, attrs \\ %{}) do
    default_attrs = %{name: "Member #{System.unique_integer()}"}
    attrs = Map.merge(default_attrs, attrs)

    GroceryPlanner.Family.create_family_member!(
      account.id,
      attrs,
      authorize?: false,
      tenant: account.id
    )
  end

  def create_recipe(account, _user, attrs \\ %{}) do
    default_attrs = %{name: "Test Recipe #{System.unique_integer()}"}
    attrs = Map.merge(default_attrs, attrs)

    GroceryPlanner.Recipes.create_recipe!(
      account.id,
      attrs,
      authorize?: false,
      tenant: account.id
    )
  end

  def set_recipe_preference(account, _user, family_member, recipe, preference) do
    GroceryPlanner.Family.set_recipe_preference!(
      account.id,
      family_member.id,
      recipe.id,
      %{preference: preference},
      authorize?: false,
      tenant: account.id
    )
  end
end
