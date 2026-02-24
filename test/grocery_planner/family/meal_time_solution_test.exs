defmodule GroceryPlanner.Family.MealTimeSolutionTest do
  use GroceryPlanner.DataCase, async: true

  alias GroceryPlanner.Family.MealTimeSolution

  import GroceryPlanner.FamilyTestHelpers

  setup do
    {account, user} = create_account_and_user()
    opts = [authorize?: false, tenant: account.id]

    %{account: account, user: user, opts: opts}
  end

  describe "compute/2" do
    test "returns error when no family members exist", %{opts: opts} do
      recipe = create_recipe(elem(create_account_and_user(), 0), nil)
      assert {:error, :no_family_members} = MealTimeSolution.compute(recipe, opts)
    end

    test "trivial solution when all members have no preferences", %{
      account: account,
      user: user,
      opts: opts
    } do
      _member1 = create_family_member(account, user, %{name: "Alice"})
      _member2 = create_family_member(account, user, %{name: "Bob"})
      recipe = create_recipe(account, user, %{name: "Pasta"})

      assert {:ok, solution} = MealTimeSolution.compute(recipe, opts)
      assert solution.primary_recipe.id == recipe.id
      assert solution.supplementary_recipes == []
      assert solution.uncoverable_members == []
      assert MealTimeSolution.complete?(solution)
    end

    test "trivial solution when no one dislikes the primary recipe", %{
      account: account,
      user: user,
      opts: opts
    } do
      member1 = create_family_member(account, user, %{name: "Alice"})
      _member2 = create_family_member(account, user, %{name: "Bob"})
      recipe = create_recipe(account, user, %{name: "Pasta"})

      # Alice has a :liked record (legacy) — still treated as "will eat it"
      set_recipe_preference(account, user, member1, recipe, :liked)

      assert {:ok, solution} = MealTimeSolution.compute(recipe, opts)
      assert solution.supplementary_recipes == []
      assert MealTimeSolution.complete?(solution)
    end

    test "one member dislikes primary, finds supplementary", %{
      account: account,
      user: user,
      opts: opts
    } do
      _member1 = create_family_member(account, user, %{name: "Alice"})
      member2 = create_family_member(account, user, %{name: "Bob"})
      recipe_a = create_recipe(account, user, %{name: "Pasta"})
      recipe_b = create_recipe(account, user, %{name: "Nuggets"})

      # Bob dislikes Pasta
      set_recipe_preference(account, user, member2, recipe_a, :disliked)

      assert {:ok, solution} = MealTimeSolution.compute(recipe_a, opts)
      assert solution.primary_recipe.id == recipe_a.id
      assert length(solution.supplementary_recipes) == 1

      [supp] = solution.supplementary_recipes
      assert supp.recipe.id == recipe_b.id
      assert Enum.any?(supp.covers, &(&1.id == member2.id))
      assert MealTimeSolution.complete?(solution)
    end

    test "greedy picks recipe covering most uncovered members", %{
      account: account,
      user: user,
      opts: opts
    } do
      member_a = create_family_member(account, user, %{name: "Alice"})
      member_b = create_family_member(account, user, %{name: "Bob"})
      member_c = create_family_member(account, user, %{name: "Charlie"})
      primary = create_recipe(account, user, %{name: "Primary"})
      alt_covers_2 = create_recipe(account, user, %{name: "Covers Two"})
      alt_covers_1 = create_recipe(account, user, %{name: "Covers One"})

      # All three dislike primary
      set_recipe_preference(account, user, member_a, primary, :disliked)
      set_recipe_preference(account, user, member_b, primary, :disliked)
      set_recipe_preference(account, user, member_c, primary, :disliked)

      # Alice and Bob dislike alt_covers_1 (so it only covers Charlie)
      set_recipe_preference(account, user, member_a, alt_covers_1, :disliked)
      set_recipe_preference(account, user, member_b, alt_covers_1, :disliked)

      # Charlie dislikes alt_covers_2 (so it covers Alice and Bob)
      set_recipe_preference(account, user, member_c, alt_covers_2, :disliked)

      assert {:ok, solution} = MealTimeSolution.compute(primary, opts)
      assert length(solution.supplementary_recipes) == 2

      # Greedy should pick alt_covers_2 first (covers 2) then alt_covers_1 (covers 1)
      [first, second] = solution.supplementary_recipes
      assert first.recipe.id == alt_covers_2.id
      assert length(first.covers) == 2
      assert second.recipe.id == alt_covers_1.id
      assert length(second.covers) == 1
      assert MealTimeSolution.complete?(solution)
    end

    test "uncoverable member who dislikes everything", %{
      account: account,
      user: user,
      opts: opts
    } do
      _member1 = create_family_member(account, user, %{name: "Alice"})
      member2 = create_family_member(account, user, %{name: "Picky Pete"})
      recipe_a = create_recipe(account, user, %{name: "Pasta"})
      recipe_b = create_recipe(account, user, %{name: "Nuggets"})

      # Picky Pete dislikes everything
      set_recipe_preference(account, user, member2, recipe_a, :disliked)
      set_recipe_preference(account, user, member2, recipe_b, :disliked)

      assert {:ok, solution} = MealTimeSolution.compute(recipe_a, opts)
      refute MealTimeSolution.complete?(solution)
      assert length(solution.uncoverable_members) == 1
      assert hd(solution.uncoverable_members).id == member2.id
    end

    test "mixed: some coverable, some not", %{
      account: account,
      user: user,
      opts: opts
    } do
      _member1 = create_family_member(account, user, %{name: "Alice"})
      member2 = create_family_member(account, user, %{name: "Bob"})
      member3 = create_family_member(account, user, %{name: "Picky"})
      recipe_a = create_recipe(account, user, %{name: "Pasta"})
      recipe_b = create_recipe(account, user, %{name: "Nuggets"})

      # Bob dislikes Pasta but will eat Nuggets
      set_recipe_preference(account, user, member2, recipe_a, :disliked)
      # Picky dislikes everything
      set_recipe_preference(account, user, member3, recipe_a, :disliked)
      set_recipe_preference(account, user, member3, recipe_b, :disliked)

      assert {:ok, solution} = MealTimeSolution.compute(recipe_a, opts)
      refute MealTimeSolution.complete?(solution)
      # Bob should be covered by Nuggets
      assert length(solution.supplementary_recipes) == 1
      [supp] = solution.supplementary_recipes
      assert supp.recipe.id == recipe_b.id
      assert Enum.any?(supp.covers, &(&1.id == member2.id))
      # Picky is uncoverable
      assert length(solution.uncoverable_members) == 1
      assert hd(solution.uncoverable_members).id == member3.id
    end

    test "all members dislike primary", %{
      account: account,
      user: user,
      opts: opts
    } do
      member1 = create_family_member(account, user, %{name: "Alice"})
      member2 = create_family_member(account, user, %{name: "Bob"})
      primary = create_recipe(account, user, %{name: "Liver"})
      alt = create_recipe(account, user, %{name: "Pizza"})

      set_recipe_preference(account, user, member1, primary, :disliked)
      set_recipe_preference(account, user, member2, primary, :disliked)

      assert {:ok, solution} = MealTimeSolution.compute(primary, opts)
      assert solution.primary_recipe.id == primary.id
      assert length(solution.supplementary_recipes) == 1
      [supp] = solution.supplementary_recipes
      assert supp.recipe.id == alt.id
      assert length(supp.covers) == 2
      assert MealTimeSolution.complete?(solution)
    end

    test "single member who dislikes primary but has alternatives", %{
      account: account,
      user: user,
      opts: opts
    } do
      member = create_family_member(account, user, %{name: "Solo"})
      recipe_a = create_recipe(account, user, %{name: "Broccoli Soup"})
      _recipe_b = create_recipe(account, user, %{name: "Fish Fingers"})

      set_recipe_preference(account, user, member, recipe_a, :disliked)

      assert {:ok, solution} = MealTimeSolution.compute(recipe_a, opts)
      assert length(solution.supplementary_recipes) == 1
      assert MealTimeSolution.complete?(solution)
    end
  end

  describe "complete?/1" do
    test "returns true when no uncoverable members" do
      solution = %MealTimeSolution{
        primary_recipe: %{id: "1"},
        supplementary_recipes: [],
        uncoverable_members: []
      }

      assert MealTimeSolution.complete?(solution)
    end

    test "returns false when uncoverable members exist" do
      solution = %MealTimeSolution{
        primary_recipe: %{id: "1"},
        supplementary_recipes: [],
        uncoverable_members: [%{id: "2", name: "Picky"}]
      }

      refute MealTimeSolution.complete?(solution)
    end
  end
end
