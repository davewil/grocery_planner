defmodule GroceryPlannerWeb.VotingLive do
  use GroceryPlannerWeb, :live_view

  on_mount {GroceryPlannerWeb.Auth, :require_authenticated_user}

  require Ash.Query

  alias GroceryPlanner.MealPlanning.Voting
  alias GroceryPlanner.Recipes.Recipe

  def mount(_params, _session, socket) do
    socket = assign(socket, :current_scope, socket.assigns.current_account)

    socket =
      socket
      |> assign(:session, nil)
      |> assign(:recipes, [])
      |> assign(:user_votes, MapSet.new())
      |> assign(:tally, %{})
      |> assign(:now, DateTime.utc_now())
      |> assign(:finalizing, false)
      |> load_session()
      |> load_recipes_and_votes()
      |> schedule_tick()

    {:ok, socket}
  end

  def handle_info(:tick, socket) do
    socket =
      socket
      |> assign(:now, DateTime.utc_now())
      |> schedule_tick()

    {:noreply, socket}
  end

  def handle_event("start_vote", _, socket) do
    try do
      case Voting.start_vote(socket.assigns.current_account.id, socket.assigns.current_user) do
        {:ok, session} ->
          socket =
            socket
            |> assign(:session, session)
            |> load_recipes_and_votes()
            |> put_flash(:info, "Voting session started")

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to start session")}
      end
    rescue
      _ ->
        {:noreply, put_flash(socket, :error, "Failed to start session")}
    end
  end

  def handle_event("vote", %{"id" => recipe_id}, socket) do
    try do
      session = socket.assigns.session
      account_id = socket.assigns.current_account.id
      user = socket.assigns.current_user

      # Check if user has already voted for this recipe
      already_voted? = MapSet.member?(socket.assigns.user_votes, recipe_id)

      result =
        if already_voted? do
          Voting.remove_vote(session.id, recipe_id, account_id, user)
        else
          Voting.cast_vote(session.id, recipe_id, account_id, user)
        end

      case result do
        {:ok, _} ->
          socket = load_recipes_and_votes(socket)
          {:noreply, socket}

        :ok ->
          socket = load_recipes_and_votes(socket)
          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update vote")}
      end
    rescue
      _ ->
        {:noreply, put_flash(socket, :error, "Failed to update vote")}
    end
  end

  def handle_event("finalize", _, socket) do
    try do
      socket = assign(socket, :finalizing, true)

      case Voting.finalize_session(
             socket.assigns.session.id,
             socket.assigns.current_account.id,
             socket.assigns.current_user
           ) do
        {:ok, result} ->
          socket =
            socket
            |> assign(:session, nil)
            |> assign(:finalizing, false)
            |> put_flash(
              :info,
              "Voting finalized: scheduled #{length(result.created_meal_plans)} meals"
            )
            |> load_recipes_and_votes()

          {:noreply, socket}

        {:error, :not_ready} ->
          {:noreply,
           socket |> assign(:finalizing, false) |> put_flash(:error, "Voting still in progress")}

        {:error, _} ->
          {:noreply,
           socket |> assign(:finalizing, false) |> put_flash(:error, "Failed to finalize")}
      end
    rescue
      _ ->
        {:noreply,
         socket |> assign(:finalizing, false) |> put_flash(:error, "Failed to finalize")}
    end
  end

  defp schedule_tick(socket) do
    if socket.assigns.session do
      Process.send_after(self(), :tick, 1000)
    end

    socket
  end

  defp load_session(socket) do
    case Voting.open_session(socket.assigns.current_account.id, socket.assigns.current_user) do
      {:ok, session} when not is_nil(session) -> assign(socket, :session, session)
      {:ok, nil} -> assign(socket, :session, nil)
    end
  end

  defp load_recipes_and_votes(socket) do
    account_id = socket.assigns.current_account.id
    user = socket.assigns.current_user

    {:ok, recipes} =
      GroceryPlanner.Recipes.list_recipes(
        actor: user,
        tenant: account_id,
        query:
          Recipe
          |> Ash.Query.filter(is_favorite == true)
          |> Ash.Query.sort(name: :asc)
      )

    {user_votes, tally} = build_vote_state(socket.assigns.session, recipes, socket)

    socket
    |> assign(:recipes, recipes)
    |> assign(:user_votes, user_votes)
    |> assign(:tally, tally)
  end

  defp build_vote_state(nil, _recipes, _socket), do: {MapSet.new(), %{}}

  defp build_vote_state(_session, recipes, socket) do
    session_id = socket.assigns.session.id
    account_id = socket.assigns.current_account.id
    user = socket.assigns.current_user

    {:ok, entries} =
      GroceryPlanner.MealPlanning.list_vote_entries(
        actor: user,
        tenant: account_id,
        query:
          GroceryPlanner.MealPlanning.MealPlanVoteEntry
          |> Ash.Query.filter(vote_session_id == ^session_id and account_id == ^account_id)
      )

    user_votes =
      entries
      |> Enum.filter(&(&1.user_id == user.id))
      |> Enum.map(& &1.recipe_id)
      |> MapSet.new()

    tally =
      entries
      |> Enum.group_by(& &1.recipe_id)
      |> Enum.map(fn {rid, votes} -> {rid, length(votes)} end)
      |> Map.new()

    tally = Enum.reduce(recipes, tally, fn r, acc -> Map.put_new(acc, r.id, 0) end)

    {user_votes, tally}
  end

  def remaining_seconds(nil, _now), do: 0

  def remaining_seconds(session, now) do
    diff = DateTime.diff(session.ends_at, now, :second)
    if diff < 0, do: 0, else: diff
  end

  defp seconds_to_hms(seconds) when seconds <= 0, do: "00:00:00"

  defp seconds_to_hms(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)

    [hours, minutes, secs]
    |> Enum.map(&String.pad_leading(to_string(&1), 2, "0"))
    |> Enum.join(":")
  end
end
