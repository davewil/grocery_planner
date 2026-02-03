defmodule GroceryPlannerWeb.InventoryLive do
  use GroceryPlannerWeb, :live_view

  on_mount({GroceryPlannerWeb.Auth, :require_authenticated_user})

  import GroceryPlannerWeb.InventoryLive.TabNavigation
  import GroceryPlannerWeb.InventoryLive.ItemsTab
  import GroceryPlannerWeb.InventoryLive.InventoryTab
  import GroceryPlannerWeb.InventoryLive.CategoriesTab
  import GroceryPlannerWeb.InventoryLive.LocationsTab
  import GroceryPlannerWeb.InventoryLive.TagsTab

  alias GroceryPlannerWeb.InventoryLive.ItemHandlers
  alias GroceryPlannerWeb.InventoryLive.EntryHandlers
  alias GroceryPlannerWeb.InventoryLive.CategoryHandlers
  alias GroceryPlannerWeb.InventoryLive.LocationHandlers
  alias GroceryPlannerWeb.InventoryLive.TagHandlers
  alias GroceryPlannerWeb.InventoryLive.DataLoader

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_account={@current_account}
      current_scope={@current_scope}
    >
      <div class="px-4 py-10 sm:px-6 lg:px-8">
        <div class="mb-8">
          <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
            <div>
              <h1 class="text-4xl font-bold text-base-content">Inventory Management</h1>
              <p class="mt-2 text-lg text-base-content/70">
                Manage your grocery items and track what's in stock
              </p>
            </div>
            <.link navigate="/receipts/scan" class="btn btn-primary gap-2 flex-shrink-0">
              <.icon name="hero-camera" class="w-5 h-5" />
              Scan Receipt
            </.link>
          </div>
          <%= if @expiring_filter do %>
            <div class="mt-4 flex flex-col sm:flex-row sm:items-center gap-2">
              <span class="inline-flex items-center gap-2 px-3 py-2 sm:px-4 bg-info/10 border border-info/20 rounded-lg text-xs sm:text-sm font-medium text-info">
                <svg
                  class="w-4 h-4 flex-shrink-0"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z"
                  />
                </svg>
                <span class="truncate">
                  Showing: {DataLoader.format_expiring_filter(@expiring_filter)}
                </span>
              </span>
              <.link
                patch="/inventory"
                class="text-xs sm:text-sm text-info hover:text-info/80 underline"
              >
                Clear filter
              </.link>
            </div>
          <% end %>
        </div>

        <div class="bg-base-100 rounded-box shadow-sm border border-base-200 overflow-hidden">
          <.tab_navigation active_tab={@active_tab} />

          <div class="p-8">
            <%= case @active_tab do %>
              <% "items" -> %>
                <.items_tab
                  items={@items}
                  tags={@tags}
                  filter_tag_ids={@filter_tag_ids}
                  show_form={@show_form}
                  form={@form}
                  editing_id={@editing_id}
                  managing_tags_for={@managing_tags_for}
                  categories={@categories}
                  selected_tag_ids={@selected_tag_ids}
                  category_suggestion={@category_suggestion}
                  category_suggestion_loading={@category_suggestion_loading}
                />
              <% "inventory" -> %>
                <.inventory_tab
                  inventory_entries={@inventory_entries}
                  show_form={@show_form}
                  form={@form}
                  items={@items}
                  storage_locations={@storage_locations}
                  page={@inventory_page}
                  per_page={@inventory_per_page}
                  total_count={@inventory_total_count}
                  total_pages={@inventory_total_pages}
                />
              <% "categories" -> %>
                <.categories_tab
                  categories={@categories}
                  show_form={@show_form}
                  form={@form}
                />
              <% "locations" -> %>
                <.locations_tab
                  storage_locations={@storage_locations}
                  show_form={@show_form}
                  form={@form}
                />
              <% "tags" -> %>
                <.tags_tab tags={@tags} show_form={@show_form} form={@form} editing_id={@editing_id} />
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:current_scope, socket.assigns.current_account)
      |> assign(:active_tab, "items")
      |> assign(:show_form, nil)
      |> assign(:form, nil)
      |> assign(:form_params, %{})
      |> assign(:editing_id, nil)
      |> assign(:managing_tags_for, nil)
      |> assign(:show_tag_modal, false)
      |> assign(:filter_tag_ids, [])
      |> assign(:selected_tag_ids, [])
      |> assign(:expiring_filter, nil)
      |> assign(:inventory_page, 1)
      |> assign(:inventory_per_page, DataLoader.inventory_per_page())
      |> assign(:inventory_total_count, 0)
      |> assign(:inventory_total_pages, 1)
      |> assign(:category_suggestion, nil)
      |> assign(:category_suggestion_loading, false)
      |> assign(:last_categorized_name, nil)

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    expiring_filter = params["expiring"]
    tab = params["tab"]

    active_tab =
      cond do
        tab -> tab
        expiring_filter -> "inventory"
        true -> socket.assigns.active_tab
      end

    socket =
      socket
      |> assign(:expiring_filter, expiring_filter)
      |> assign(:active_tab, active_tab)
      |> assign(:inventory_page, 1)
      |> DataLoader.load_data()

    {:noreply, socket}
  end

  # Tab and pagination events (kept in main module)
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("inventory_page", %{"page" => page}, socket) do
    page = String.to_integer(page)

    socket =
      socket
      |> assign(:inventory_page, page)
      |> DataLoader.load_data()

    {:noreply, socket}
  end

  def handle_event("cancel_form", _, socket) do
    {:noreply,
     assign(socket,
       show_form: nil,
       form: nil,
       editing_id: nil,
       category_suggestion: nil,
       category_suggestion_loading: false,
       last_categorized_name: nil
     )}
  end

  # Delegate item events
  def handle_event("new_item" = event, params, socket),
    do: ItemHandlers.handle_event(event, params, socket)

  def handle_event("edit_item" = event, params, socket),
    do: ItemHandlers.handle_event(event, params, socket)

  def handle_event("validate_item" = event, params, socket),
    do: ItemHandlers.handle_event(event, params, socket)

  def handle_event("save_item" = event, params, socket),
    do: ItemHandlers.handle_event(event, params, socket)

  def handle_event("delete_item" = event, params, socket),
    do: ItemHandlers.handle_event(event, params, socket)

  def handle_event("suggest_category" = event, params, socket),
    do: ItemHandlers.handle_event(event, params, socket)

  def handle_event("accept_suggestion" = event, params, socket),
    do: ItemHandlers.handle_event(event, params, socket)

  def handle_event("toggle_form_tag" = event, params, socket),
    do: ItemHandlers.handle_event(event, params, socket)

  # Delegate entry events
  def handle_event("new_entry" = event, params, socket),
    do: EntryHandlers.handle_event(event, params, socket)

  def handle_event("save_entry" = event, params, socket),
    do: EntryHandlers.handle_event(event, params, socket)

  def handle_event("delete_entry" = event, params, socket),
    do: EntryHandlers.handle_event(event, params, socket)

  def handle_event("consume_entry" = event, params, socket),
    do: EntryHandlers.handle_event(event, params, socket)

  def handle_event("expire_entry" = event, params, socket),
    do: EntryHandlers.handle_event(event, params, socket)

  def handle_event("bulk_mark_expired" = event, params, socket),
    do: EntryHandlers.handle_event(event, params, socket)

  def handle_event("bulk_consume_available" = event, params, socket),
    do: EntryHandlers.handle_event(event, params, socket)

  # Delegate category events
  def handle_event("new_category" = event, params, socket),
    do: CategoryHandlers.handle_event(event, params, socket)

  def handle_event("save_category" = event, params, socket),
    do: CategoryHandlers.handle_event(event, params, socket)

  def handle_event("delete_category" = event, params, socket),
    do: CategoryHandlers.handle_event(event, params, socket)

  # Delegate location events
  def handle_event("new_location" = event, params, socket),
    do: LocationHandlers.handle_event(event, params, socket)

  def handle_event("save_location" = event, params, socket),
    do: LocationHandlers.handle_event(event, params, socket)

  def handle_event("delete_location" = event, params, socket),
    do: LocationHandlers.handle_event(event, params, socket)

  # Delegate tag events
  def handle_event("new_tag" = event, params, socket),
    do: TagHandlers.handle_event(event, params, socket)

  def handle_event("save_tag" = event, params, socket),
    do: TagHandlers.handle_event(event, params, socket)

  def handle_event("edit_tag" = event, params, socket),
    do: TagHandlers.handle_event(event, params, socket)

  def handle_event("delete_tag" = event, params, socket),
    do: TagHandlers.handle_event(event, params, socket)

  def handle_event("manage_tags" = event, params, socket),
    do: TagHandlers.handle_event(event, params, socket)

  def handle_event("add_tag_to_item" = event, params, socket),
    do: TagHandlers.handle_event(event, params, socket)

  def handle_event("remove_tag_from_item" = event, params, socket),
    do: TagHandlers.handle_event(event, params, socket)

  def handle_event("cancel_tag_management" = event, params, socket),
    do: TagHandlers.handle_event(event, params, socket)

  def handle_event("toggle_tag_filter" = event, params, socket),
    do: TagHandlers.handle_event(event, params, socket)

  def handle_event("clear_tag_filters" = event, params, socket),
    do: TagHandlers.handle_event(event, params, socket)

  # Handle async category suggestion results
  def handle_info({:category_suggestion_result, item_name, result}, socket) do
    current_name = get_in(socket.assigns, [:form_params, "name"]) || ""

    if current_name == item_name do
      socket =
        case result do
          {:ok,
           %{
             category: predicted_category,
             confidence: confidence,
             confidence_level: confidence_level
           }} ->
            case Enum.find(socket.assigns.categories, fn c ->
                   String.downcase(c.name) == String.downcase(predicted_category)
                 end) do
              nil ->
                assign(socket, category_suggestion: nil, category_suggestion_loading: false)

              category ->
                assign(socket,
                  category_suggestion: %{
                    category: category,
                    confidence: confidence,
                    confidence_level: to_string(confidence_level)
                  },
                  category_suggestion_loading: false
                )
            end

          {:error, _} ->
            assign(socket, category_suggestion: nil, category_suggestion_loading: false)
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Public helper for handler modules to reload data
  def load_data(socket), do: DataLoader.load_data(socket)
end
