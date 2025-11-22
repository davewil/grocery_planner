defmodule GroceryPlanner.Notifications.ExpirationAlerts do
  @moduledoc """
  Functions for generating expiration alerts and notifications.
  """

  require Ash.Query
  alias GroceryPlanner.Inventory

  @doc """
  Get all inventory entries expiring within the specified number of days.
  Returns a map grouped by urgency: :expired, :today, :tomorrow, :this_week, :soon
  """
  def get_expiring_items(account_id, actor, opts \\ []) do
    days_threshold = Keyword.get(opts, :days_threshold, 7)

    {:ok, all_entries} = Inventory.list_inventory_entries(
      actor: actor,
      tenant: account_id,
      query: GroceryPlanner.Inventory.InventoryEntry
        |> Ash.Query.filter(status == :available)
        |> Ash.Query.filter(not is_nil(use_by_date))
        |> Ash.Query.load([:grocery_item, :days_until_expiry, :is_expired, :is_expiring_soon])
        |> Ash.Query.sort(use_by_date: :asc)
    )

    # Filter to only items expiring within threshold or already expired
    expiring_entries = Enum.filter(all_entries, fn entry ->
      entry.is_expired || (entry.days_until_expiry && entry.days_until_expiry <= days_threshold)
    end)

    # Group by urgency
    grouped = Enum.group_by(expiring_entries, &categorize_urgency/1)

    {:ok, %{
      expired: Map.get(grouped, :expired, []),
      today: Map.get(grouped, :today, []),
      tomorrow: Map.get(grouped, :tomorrow, []),
      this_week: Map.get(grouped, :this_week, []),
      soon: Map.get(grouped, :soon, []),
      total_count: length(expiring_entries)
    }}
  end

  @doc """
  Get a summary count of expiring items by urgency.
  """
  def get_expiring_summary(account_id, actor, opts \\ []) do
    case get_expiring_items(account_id, actor, opts) do
      {:ok, alerts} ->
        {:ok, %{
          expired_count: length(alerts.expired),
          today_count: length(alerts.today),
          tomorrow_count: length(alerts.tomorrow),
          this_week_count: length(alerts.this_week),
          soon_count: length(alerts.soon),
          total_count: alerts.total_count
        }}

      error -> error
    end
  end

  @doc """
  Check if there are any critical alerts (expired or expiring today).
  """
  def has_critical_alerts?(account_id, actor) do
    case get_expiring_summary(account_id, actor) do
      {:ok, summary} ->
        summary.expired_count > 0 || summary.today_count > 0

      _error -> false
    end
  end

  # Private helpers

  defp categorize_urgency(entry) do
    cond do
      entry.is_expired ->
        :expired

      entry.days_until_expiry == 0 ->
        :today

      entry.days_until_expiry == 1 ->
        :tomorrow

      entry.days_until_expiry && entry.days_until_expiry <= 3 ->
        :this_week

      true ->
        :soon
    end
  end
end
