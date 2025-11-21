defmodule GroceryPlanner.MealPlanning.Voting do
  require Ash.Query
  alias GroceryPlanner.MealPlanning.MealPlanVoteSession
  alias GroceryPlanner.MealPlanning.MealPlanVoteEntry
  alias GroceryPlanner.MealPlanning.MealPlan
  alias Ash.Query
  alias Ash.Changeset

  def start_vote(account_id, actor) do
    MealPlanVoteSession
    |> Changeset.new()
    |> Changeset.set_argument(:account_id, account_id)
    |> Changeset.for_create(:start, %{})
    |> Ash.create(actor: actor, tenant: account_id)
  end

  def open_session(account_id, actor) do
    sessions =
      MealPlanVoteSession
      |> Ash.read!(tenant: account_id, actor: actor)
      |> Enum.filter(fn session ->
        session.account_id == account_id && session.status == :open
      end)

    case sessions do
      [session | _] -> {:ok, session}
      [] -> {:ok, nil}
    end
  end

  def voting_active?(account_id, actor) do
    case open_session(account_id, actor) do
      {:ok, session} when not is_nil(session) -> true
      _ -> false
    end
  end

  def cast_vote(session_id, recipe_id, account_id, actor) do
    MealPlanVoteEntry
    |> Changeset.new()
    |> Changeset.set_argument(:account_id, account_id)
    |> Changeset.set_argument(:vote_session_id, session_id)
    |> Changeset.set_argument(:recipe_id, recipe_id)
    |> Changeset.set_argument(:user_id, actor.id)
    |> Changeset.for_create(:vote, %{})
    |> Ash.create(actor: actor, tenant: account_id)
  end

  def remove_vote(session_id, recipe_id, account_id, actor) do
    entries =
      MealPlanVoteEntry
      |> Query.filter(vote_session_id == ^session_id and recipe_id == ^recipe_id and user_id == ^actor.id)
      |> Ash.read!(actor: actor, tenant: account_id)

    case entries do
      [entry] -> Ash.destroy(entry, actor: actor, tenant: account_id)
      [] -> {:ok, nil}
      _ -> {:error, :multiple_entries}
    end
  end

  def finalize_session(session_id, account_id, actor) do
    with {:ok, session} <- Ash.get(MealPlanVoteSession, session_id, tenant: account_id, actor: actor),
         true <- session.status in [:open, :closed],
         true <- DateTime.compare(DateTime.utc_now(), session.ends_at) != :lt,
         {:ok, entries} <- list_entries(session_id, account_id, actor) do
      winning_recipe_ids = pick_winners(entries)
      {:ok, _} = mark_processed(session, winning_recipe_ids, account_id, actor)
      {:ok, created_meals} = distribute_winners(winning_recipe_ids, account_id, actor)
      {:ok, %{winning_recipe_ids: winning_recipe_ids, created_meal_plans: created_meals}}
    else
      false -> {:error, :not_ready}
      {:error, error} -> {:error, error}
      _ -> {:error, :finalize_failed}
    end
  end

  defp list_entries(session_id, account_id, actor) do
    MealPlanVoteEntry
    |> Query.filter([account_id: account_id, vote_session_id: session_id])
    |> Ash.read(actor: actor, tenant: account_id)
  end

  defp pick_winners(entries) do
    entries
    |> Enum.group_by(& &1.recipe_id)
    |> Enum.map(fn {recipe_id, votes} -> {recipe_id, length(votes)} end)
    |> Enum.group_by(fn {_recipe_id, count} -> count end)
    |> Enum.sort_by(fn {count, _list} -> count end, :desc)
    |> Enum.flat_map(fn {_count, list} -> Enum.shuffle(list) end)
    |> Enum.map(fn {recipe_id, _count} -> recipe_id end)
  end

  defp mark_processed(session, winning_recipe_ids, account_id, actor) do
    session
    |> Changeset.for_update(:mark_processed, %{winning_recipe_ids: winning_recipe_ids})
    |> Ash.update(actor: actor, tenant: account_id)
  end

  defp distribute_winners(winning_recipe_ids, account_id, actor) do
    week_start = next_week_start(Date.utc_today())
    dates = Enum.map(0..6, fn i -> Date.add(week_start, i) end)
    dinner_slot_count = length(dates)
    chosen = Enum.take(winning_recipe_ids, dinner_slot_count)
    created =
      Enum.reduce(Enum.zip(dates, chosen), [], fn {date, recipe_id}, acc ->
        case create_meal_plan(date, recipe_id, account_id, actor) do
          {:ok, meal} -> [meal | acc]
          {:error, _} -> acc
        end
      end)
    {:ok, Enum.reverse(created)}
  end

  defp create_meal_plan(date, recipe_id, account_id, actor) do
    MealPlan
    |> Changeset.new()
    |> Changeset.set_argument(:account_id, account_id)
    |> Changeset.for_create(:create, %{
      recipe_id: recipe_id,
      scheduled_date: date,
      meal_type: :dinner,
      servings: 4
    })
    |> Ash.create(actor: actor, tenant: account_id)
  end

  defp next_week_start(today) do
    this_week_start = get_week_start(today)
    Date.add(this_week_start, 7)
  end

  defp get_week_start(date) do
    dow = Date.day_of_week(date)
    Date.add(date, -(dow - 1))
  end
end