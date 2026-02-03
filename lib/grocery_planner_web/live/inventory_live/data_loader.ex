defmodule GroceryPlannerWeb.InventoryLive.DataLoader do
  @moduledoc """
  Shared data loading functions for InventoryLive.
  """

  import Phoenix.Component, only: [assign: 3]
  alias GroceryPlanner.Inventory

  @inventory_per_page 12

  def load_data(socket) do
    account_id = socket.assigns.current_account.id
    user = socket.assigns.current_user

    filter_tag_ids =
      if socket.assigns[:filter_tag_ids] && socket.assigns.filter_tag_ids != [] do
        socket.assigns.filter_tag_ids
      else
        nil
      end

    {:ok, items} =
      Inventory.list_items_with_tags(
        filter_tag_ids,
        actor: user,
        tenant: account_id
      )

    {:ok, categories} = Inventory.list_categories(actor: user, tenant: account_id)

    {:ok, locations} =
      Inventory.list_storage_locations(actor: user, tenant: account_id)

    {:ok, tags} =
      Inventory.list_grocery_item_tags(authorize?: false, tenant: account_id)

    expiration_filter =
      case socket.assigns[:expiring_filter] do
        "expired" -> :expired
        "today" -> :today
        "tomorrow" -> :tomorrow
        "this_week" -> :this_week
        _ -> nil
      end

    {:ok, all_entries} =
      Inventory.list_inventory_entries_filtered(
        %{
          status: :available,
          expiration_filter: expiration_filter
        },
        actor: user,
        tenant: account_id
      )

    page = socket.assigns[:inventory_page] || 1
    per_page = socket.assigns[:inventory_per_page] || @inventory_per_page
    total_count = length(all_entries)
    total_pages = max(1, ceil(total_count / per_page))

    entries =
      all_entries
      |> Enum.drop((page - 1) * per_page)
      |> Enum.take(per_page)

    socket
    |> assign(:items, items)
    |> assign(:categories, categories)
    |> assign(:storage_locations, locations)
    |> assign(:inventory_entries, entries)
    |> assign(:inventory_total_count, total_count)
    |> assign(:inventory_total_pages, total_pages)
    |> assign(:tags, tags)
  end

  def format_expiring_filter("expired"), do: "Expired Items"
  def format_expiring_filter("today"), do: "Expires Today"
  def format_expiring_filter("tomorrow"), do: "Expires Tomorrow"
  def format_expiring_filter("this_week"), do: "Expires This Week (2-3 days)"
  def format_expiring_filter(_), do: "All Items"

  def inventory_per_page, do: @inventory_per_page
end
