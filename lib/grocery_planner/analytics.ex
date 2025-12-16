defmodule GroceryPlanner.Analytics do
  @moduledoc """
  Provides analytics and aggregated metrics for the Grocery Planner application.
  """

  use Ash.Domain,
    extensions: [AshJsonApi.Domain]

  json_api do
    prefix("/api/json")
  end

  require Ash.Query

  resources do
    resource GroceryPlanner.Analytics.UsageLog do
      define(:list_usage_logs, action: :read)
    end
  end

  alias GroceryPlanner.Inventory
  alias GroceryPlanner.Inventory.{GroceryItem, InventoryEntry}
  alias GroceryPlanner.Analytics.UsageLog

  @doc """
  Returns a summary of the inventory for a given account.
  """
  def get_inventory_summary(account_id, currency, actor) do
    # Total unique items
    {:ok, total_items} =
      GroceryItem
      |> Ash.Query.for_read(:read, %{}, actor: actor, tenant: account_id)
      |> Ash.count(domain: Inventory)

    # Total entries (instances)
    {:ok, total_entries} =
      InventoryEntry
      |> Ash.Query.filter(status == :available)
      |> Ash.Query.for_read(:read, %{}, actor: actor, tenant: account_id)
      |> Ash.count(domain: Inventory)

    # Total value
    # Note: AshMoney aggregation might be tricky directly in DB depending on currency.
    # For now, we'll fetch available entries with price and sum in memory to be safe/simple.
    # Optimization: Use database aggregation if AshMoney supports it seamlessly.
    {:ok, entries_with_price} =
      Inventory.list_inventory_entries(
        actor: actor,
        tenant: account_id,
        query:
          InventoryEntry
          |> Ash.Query.filter(status == :available and not is_nil(purchase_price))
          |> Ash.Query.load([:purchase_price])
      )

    total_value =
      Enum.reduce(entries_with_price, Money.new(0, currency), fn entry, acc ->
        if entry.purchase_price do
          Money.add!(acc, entry.purchase_price)
        else
          acc
        end
      end)

    %{
      total_items: total_items,
      total_entries: total_entries,
      total_value: total_value
    }
  end

  @doc """
  Returns a summary of expiration status.
  """
  def get_expiration_summary(account_id, actor) do
    base_query =
      InventoryEntry
      |> Ash.Query.filter(status == :available)
      |> Ash.Query.filter(not is_nil(use_by_date))

    # Expired
    {:ok, expired_count} =
      base_query
      |> Ash.Query.filter(is_expired == true)
      |> Ash.Query.for_read(:read, %{}, actor: actor, tenant: account_id)
      |> Ash.count(domain: Inventory)

    # Expiring within 7 days
    {:ok, expiring_7_days} =
      base_query
      |> Ash.Query.filter(is_expired == false)
      |> Ash.Query.filter(days_until_expiry <= 7)
      |> Ash.Query.for_read(:read, %{}, actor: actor, tenant: account_id)
      |> Ash.count(domain: Inventory)

    # Expiring within 30 days
    {:ok, expiring_30_days} =
      base_query
      |> Ash.Query.filter(is_expired == false)
      |> Ash.Query.filter(days_until_expiry <= 30)
      |> Ash.Query.for_read(:read, %{}, actor: actor, tenant: account_id)
      |> Ash.count(domain: Inventory)

    %{
      expired_count: expired_count,
      expiring_7_days: expiring_7_days,
      expiring_30_days: expiring_30_days
    }
  end

  @doc """
  Returns item counts broken down by category.
  """
  def get_category_breakdown(account_id, actor) do
    # We want to count items per category.
    # Since Ash doesn't support "GROUP BY" in a simple read action returning a map,
    # we can fetch categories and load their item count.

    {:ok, categories} =
      Inventory.list_categories(
        actor: actor,
        tenant: account_id,
        query:
          GroceryPlanner.Inventory.Category
          |> Ash.Query.load([:item_count])
          |> Ash.Query.sort(name: :asc)
      )

    # If we don't have item_count aggregate on Category yet, we need to add it.
    # For now, let's assume we will add it.
    categories
    |> Enum.map(fn cat ->
      %{
        name: cat.name,
        count: cat.item_count || 0
      }
    end)
  end

  @doc """
  Returns waste statistics for the account.
  """
  def get_waste_stats(account_id, currency, actor) do
    # Total consumed
    {:ok, consumed_count} =
      UsageLog
      |> Ash.Query.filter(reason == :consumed)
      |> Ash.Query.for_read(:read, %{}, actor: actor, tenant: account_id)
      |> Ash.count(domain: GroceryPlanner.Analytics)

    # Total wasted (expired or wasted)
    {:ok, wasted_count} =
      UsageLog
      |> Ash.Query.filter(reason in [:expired, :wasted])
      |> Ash.Query.for_read(:read, %{}, actor: actor, tenant: account_id)
      |> Ash.count(domain: GroceryPlanner.Analytics)

    # Total cost of waste
    {:ok, wasted_logs} =
      __MODULE__.list_usage_logs(
        query:
          UsageLog
          |> Ash.Query.filter(reason in [:expired, :wasted])
          |> Ash.Query.filter(not is_nil(cost))
          |> Ash.Query.load([:cost]),
        actor: actor,
        tenant: account_id
      )

    total_wasted_cost =
      Enum.reduce(wasted_logs, Money.new(0, currency), fn log, acc ->
        if log.cost do
          Money.add!(acc, log.cost)
        else
          acc
        end
      end)

    total_logs = consumed_count + wasted_count

    waste_percentage =
      if total_logs > 0 do
        wasted_count / total_logs * 100
      else
        0.0
      end

    %{
      consumed_count: consumed_count,
      wasted_count: wasted_count,
      total_wasted_cost: total_wasted_cost,
      waste_percentage: waste_percentage
    }
  end

  @doc """
  Returns spending trends over the last n days.
  """
  def get_spending_trends(account_id, currency, actor, days \\ 30) do
    cutoff_date = Date.add(Date.utc_today(), -days)

    {:ok, entries} =
      Inventory.list_inventory_entries(
        query:
          InventoryEntry
          |> Ash.Query.filter(purchase_date >= ^cutoff_date)
          |> Ash.Query.filter(not is_nil(purchase_price))
          |> Ash.Query.load([:purchase_price])
          |> Ash.Query.sort(purchase_date: :asc),
        actor: actor,
        tenant: account_id
      )

    # Group by date and sum
    entries
    |> Enum.group_by(& &1.purchase_date)
    |> Enum.map(fn {date, daily_entries} ->
      total =
        Enum.reduce(daily_entries, Money.new(0, currency), fn entry, acc ->
          if entry.purchase_price do
            Money.add!(acc, entry.purchase_price)
          else
            acc
          end
        end)

      %{date: date, amount: total}
    end)
    |> Enum.sort_by(& &1.date, Date)
  end

  @doc """
  Returns usage trends (consumed vs wasted) over the last n days.
  """
  def get_usage_trends(account_id, actor, days \\ 30) do
    cutoff_date = Date.add(Date.utc_today(), -days)

    {:ok, logs} =
      __MODULE__.list_usage_logs(
        query:
          UsageLog
          |> Ash.Query.filter(occurred_at >= ^cutoff_date)
          |> Ash.Query.sort(occurred_at: :asc),
        actor: actor,
        tenant: account_id
      )

    # Group by date and reason
    logs
    |> Enum.group_by(&Date.to_iso8601(&1.occurred_at))
    |> Enum.map(fn {date_str, daily_logs} ->
      consumed = Enum.count(daily_logs, &(&1.reason == :consumed))
      wasted = Enum.count(daily_logs, &(&1.reason in [:expired, :wasted]))
      %{date: date_str, consumed: consumed, wasted: wasted}
    end)
    |> Enum.sort_by(& &1.date)
  end

  @doc """
  Returns the most wasted items.
  """
  def get_most_wasted_items(account_id, currency, actor, limit \\ 5) do
    {:ok, wasted_logs} =
      __MODULE__.list_usage_logs(
        query:
          UsageLog
          |> Ash.Query.filter(reason in [:expired, :wasted])
          |> Ash.Query.load([:grocery_item, :cost]),
        actor: actor,
        tenant: account_id
      )

    wasted_logs
    |> Enum.group_by(& &1.grocery_item_id)
    |> Enum.map(fn {item_id, logs} ->
      first_log = List.first(logs)
      item_name = if first_log.grocery_item, do: first_log.grocery_item.name, else: "Unknown Item"
      count = length(logs)

      total_cost =
        Enum.reduce(logs, Money.new(0, currency), fn log, acc ->
          if log.cost do
            Money.add!(acc, log.cost)
          else
            acc
          end
        end)

      %{
        id: item_id,
        name: item_name,
        count: count,
        total_cost: total_cost
      }
    end)
    |> Enum.sort_by(& &1.count, :desc)
    |> Enum.take(limit)
  end
end
