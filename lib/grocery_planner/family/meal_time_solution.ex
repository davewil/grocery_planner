defmodule GroceryPlanner.Family.MealTimeSolution do
  @moduledoc """
  Computes meal time solutions from a selected recipe.

  Given a primary recipe, determines the minimum set of recipes needed
  to feed every family member. Uses a greedy set cover algorithm.

  Two-state preference model:
  - No :disliked record = assumed liking (member will eat it)
  - :disliked record = active dislike (member won't eat it)
  """

  alias GroceryPlanner.Family
  alias GroceryPlanner.Recipes

  defstruct [
    :primary_recipe,
    covered_by_primary: [],
    supplementary_recipes: [],
    uncoverable_members: [],
    excluded_members: []
  ]

  @type t :: %__MODULE__{
          primary_recipe: map(),
          covered_by_primary: [map()],
          supplementary_recipes: [%{recipe: map(), covers: [map()]}],
          uncoverable_members: [map()],
          excluded_members: [map()]
        }

  @doc """
  Returns true if the solution covers all family members.
  """
  def complete?(%__MODULE__{uncoverable_members: []}), do: true
  def complete?(%__MODULE__{}), do: false

  @doc """
  Builds a map of member_id => %{member, recipe, is_primary} assignments.
  """
  def member_assignments(%__MODULE__{} = solution) do
    primary_assignments =
      Map.new(solution.covered_by_primary, fn member ->
        {member.id, %{member: member, recipe: solution.primary_recipe, is_primary: true}}
      end)

    supplementary_assignments =
      Enum.flat_map(solution.supplementary_recipes, fn %{recipe: recipe, covers: members} ->
        Enum.map(members, fn member ->
          {member.id, %{member: member, recipe: recipe, is_primary: false}}
        end)
      end)
      |> Map.new()

    Map.merge(primary_assignments, supplementary_assignments)
  end

  @doc """
  Computes a meal time solution for the given primary recipe.

  Returns `{:ok, %MealTimeSolution{}}` or `{:error, :no_family_members}`.
  """
  @spec compute(map(), keyword()) :: {:ok, t()} | {:error, :no_family_members}
  def compute(primary_recipe, opts \\ []) do
    {exclude_member_ids, opts} = Keyword.pop(opts, :exclude_member_ids, MapSet.new())
    all_members = Family.list_family_members!(opts)

    if all_members == [] do
      {:error, :no_family_members}
    else
      {excluded, active} =
        Enum.split_with(all_members, fn m -> MapSet.member?(exclude_member_ids, m.id) end)

      if active == [] do
        {:ok,
         %__MODULE__{
           primary_recipe: primary_recipe,
           excluded_members: excluded
         }}
      else
        case compute_solution(primary_recipe, active, opts) do
          {:ok, solution} -> {:ok, %{solution | excluded_members: excluded}}
          error -> error
        end
      end
    end
  end

  defp compute_solution(primary_recipe, members, opts) do
    # Step 2-3: Partition members by dislike of primary recipe
    {covered, uncovered} = partition_members(primary_recipe, members, opts)

    if uncovered == [] do
      # Trivial solution: everyone eats the primary recipe
      {:ok,
       %__MODULE__{
         primary_recipe: primary_recipe,
         covered_by_primary: covered,
         supplementary_recipes: [],
         uncoverable_members: []
       }}
    else
      # Steps 5-7: Find supplementary recipes via greedy set cover
      all_recipes = load_all_recipes(opts)
      # Exclude the primary recipe from candidates
      candidate_recipes = Enum.reject(all_recipes, &(&1.id == primary_recipe.id))
      dislike_map = build_dislike_map(uncovered, opts)

      {supplementary, still_uncovered} =
        greedy_cover(uncovered, candidate_recipes, dislike_map)

      {:ok,
       %__MODULE__{
         primary_recipe: primary_recipe,
         covered_by_primary: covered,
         supplementary_recipes: supplementary,
         uncoverable_members: still_uncovered
       }}
    end
  end

  defp partition_members(primary_recipe, members, opts) do
    # Load :disliked preferences for the primary recipe
    preferences = Family.list_preferences_for_recipe!(primary_recipe.id, opts)

    disliked_member_ids =
      preferences
      |> Enum.filter(&(&1.preference == :disliked))
      |> MapSet.new(& &1.family_member_id)

    Enum.split_with(members, fn member ->
      not MapSet.member?(disliked_member_ids, member.id)
    end)
  end

  defp load_all_recipes(opts) do
    Recipes.list_recipes_sorted!(opts)
  end

  defp build_dislike_map(uncovered_members, opts) do
    # For each uncovered member, load their :disliked preferences
    # Returns %{member_id => MapSet of disliked recipe_ids}
    Map.new(uncovered_members, fn member ->
      preferences = Family.list_preferences_for_member!(member.id, opts)

      disliked_ids =
        preferences
        |> Enum.filter(&(&1.preference == :disliked))
        |> MapSet.new(& &1.recipe_id)

      {member.id, disliked_ids}
    end)
  end

  defp greedy_cover(uncovered_members, candidate_recipes, dislike_map) do
    greedy_cover(uncovered_members, candidate_recipes, dislike_map, [])
  end

  defp greedy_cover([], _candidates, _dislike_map, acc) do
    {Enum.reverse(acc), []}
  end

  defp greedy_cover(uncovered, candidates, dislike_map, acc) do
    # For each candidate recipe, count how many uncovered members can eat it
    # (i.e., do NOT have it in their dislike set)
    best =
      candidates
      |> Enum.map(fn recipe ->
        covers =
          Enum.filter(uncovered, fn member ->
            disliked = Map.get(dislike_map, member.id, MapSet.new())
            not MapSet.member?(disliked, recipe.id)
          end)

        {recipe, covers}
      end)
      |> Enum.max_by(fn {_recipe, covers} -> length(covers) end, fn -> nil end)

    case best do
      nil ->
        # No candidates left
        {Enum.reverse(acc), uncovered}

      {_recipe, []} ->
        # No candidate covers any remaining member
        {Enum.reverse(acc), uncovered}

      {recipe, covers} ->
        covered_ids = MapSet.new(covers, & &1.id)
        remaining = Enum.reject(uncovered, &MapSet.member?(covered_ids, &1.id))
        entry = %{recipe: recipe, covers: covers}
        greedy_cover(remaining, candidates, dislike_map, [entry | acc])
    end
  end
end
