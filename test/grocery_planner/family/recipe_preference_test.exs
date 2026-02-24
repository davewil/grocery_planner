defmodule GroceryPlanner.Family.RecipePreferenceTest do
  use GroceryPlanner.DataCase, async: true

  import GroceryPlanner.FamilyTestHelpers

  alias GroceryPlanner.Family

  describe "set_preference" do
    test "creates a liked preference" do
      {account, user} = create_account_and_user()
      member = create_family_member(account, user)
      recipe = create_recipe(account, user)

      assert {:ok, pref} =
               Family.set_recipe_preference(
                 account.id,
                 member.id,
                 recipe.id,
                 %{preference: :liked},
                 actor: user,
                 tenant: account.id
               )

      assert pref.preference == :liked
      assert pref.family_member_id == member.id
      assert pref.recipe_id == recipe.id
    end

    test "creates a disliked preference" do
      {account, user} = create_account_and_user()
      member = create_family_member(account, user)
      recipe = create_recipe(account, user)

      assert {:ok, pref} =
               Family.set_recipe_preference(
                 account.id,
                 member.id,
                 recipe.id,
                 %{preference: :disliked},
                 actor: user,
                 tenant: account.id
               )

      assert pref.preference == :disliked
    end

    test "upserts: setting again updates, does not duplicate" do
      {account, user} = create_account_and_user()
      member = create_family_member(account, user)
      recipe = create_recipe(account, user)

      # Set liked
      {:ok, _pref1} =
        Family.set_recipe_preference(
          account.id,
          member.id,
          recipe.id,
          %{preference: :liked},
          actor: user,
          tenant: account.id
        )

      # Change to disliked
      {:ok, pref2} =
        Family.set_recipe_preference(
          account.id,
          member.id,
          recipe.id,
          %{preference: :disliked},
          actor: user,
          tenant: account.id
        )

      assert pref2.preference == :disliked

      # Should be the same record (upsert), not a new one
      all_prefs = Family.list_recipe_preferences!(actor: user, tenant: account.id)

      recipe_prefs =
        Enum.filter(all_prefs, &(&1.recipe_id == recipe.id && &1.family_member_id == member.id))

      assert length(recipe_prefs) == 1
    end
  end

  describe "read actions" do
    test "list_preferences_for_recipe returns preferences for a specific recipe" do
      {account, user} = create_account_and_user()
      member1 = create_family_member(account, user, %{name: "Sam"})
      member2 = create_family_member(account, user, %{name: "Lily"})
      recipe = create_recipe(account, user)
      other_recipe = create_recipe(account, user)

      set_recipe_preference(account, user, member1, recipe, :liked)
      set_recipe_preference(account, user, member2, recipe, :disliked)
      set_recipe_preference(account, user, member1, other_recipe, :liked)

      prefs = Family.list_preferences_for_recipe!(recipe.id, actor: user, tenant: account.id)

      assert length(prefs) == 2
      assert Enum.all?(prefs, &(&1.recipe_id == recipe.id))
    end

    test "list_preferences_for_recipes batch-loads for multiple recipe IDs" do
      {account, user} = create_account_and_user()
      member = create_family_member(account, user)
      recipe1 = create_recipe(account, user)
      recipe2 = create_recipe(account, user)
      recipe3 = create_recipe(account, user)

      set_recipe_preference(account, user, member, recipe1, :liked)
      set_recipe_preference(account, user, member, recipe2, :disliked)

      prefs =
        Family.list_preferences_for_recipes!(
          [recipe1.id, recipe2.id, recipe3.id],
          actor: user,
          tenant: account.id
        )

      assert length(prefs) == 2
      pref_recipe_ids = Enum.map(prefs, & &1.recipe_id)
      assert recipe1.id in pref_recipe_ids
      assert recipe2.id in pref_recipe_ids
      refute recipe3.id in pref_recipe_ids
    end

    test "list_preferences_for_member returns preferences for a specific member" do
      {account, user} = create_account_and_user()
      member = create_family_member(account, user)
      other_member = create_family_member(account, user)
      recipe1 = create_recipe(account, user)
      recipe2 = create_recipe(account, user)

      set_recipe_preference(account, user, member, recipe1, :liked)
      set_recipe_preference(account, user, member, recipe2, :disliked)
      set_recipe_preference(account, user, other_member, recipe1, :liked)

      prefs = Family.list_preferences_for_member!(member.id, actor: user, tenant: account.id)

      assert length(prefs) == 2
      assert Enum.all?(prefs, &(&1.family_member_id == member.id))
    end
  end

  describe "destroy" do
    test "destroys a preference" do
      {account, user} = create_account_and_user()
      member = create_family_member(account, user)
      recipe = create_recipe(account, user)

      pref = set_recipe_preference(account, user, member, recipe, :liked)

      assert :ok = Family.destroy_recipe_preference(pref, actor: user, tenant: account.id)

      prefs = Family.list_preferences_for_recipe!(recipe.id, actor: user, tenant: account.id)
      assert prefs == []
    end
  end

  describe "authorization" do
    test "denies cross-account preference creation" do
      {account1, _user1} = create_account_and_user()
      {_account2, user2} = create_account_and_user()
      member = create_family_member(account1, nil)
      recipe = create_recipe(account1, nil)

      assert {:error, error} =
               Family.set_recipe_preference(
                 account1.id,
                 member.id,
                 recipe.id,
                 %{preference: :liked},
                 actor: user2,
                 tenant: account1.id
               )

      assert error.class == :forbidden
    end

    test "denies cross-account preference read" do
      {account1, user1} = create_account_and_user()
      {_account2, user2} = create_account_and_user()
      member = create_family_member(account1, user1)
      recipe = create_recipe(account1, user1)

      set_recipe_preference(account1, user1, member, recipe, :liked)

      prefs = Family.list_preferences_for_recipe!(recipe.id, actor: user2, tenant: account1.id)
      assert prefs == []
    end

    test "denies cross-account preference destroy" do
      {account1, user1} = create_account_and_user()
      {_account2, user2} = create_account_and_user()
      member = create_family_member(account1, user1)
      recipe = create_recipe(account1, user1)

      pref = set_recipe_preference(account1, user1, member, recipe, :liked)

      assert {:error, error} =
               Family.destroy_recipe_preference(pref, actor: user2, tenant: account1.id)

      assert error.class == :forbidden
    end
  end
end
