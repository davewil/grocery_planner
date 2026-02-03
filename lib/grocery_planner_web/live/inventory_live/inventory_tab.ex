defmodule GroceryPlannerWeb.InventoryLive.InventoryTab do
  use GroceryPlannerWeb, :html

  attr(:inventory_entries, :list, required: true)
  attr(:show_form, :atom, default: nil)
  attr(:form, :any, default: nil)
  attr(:items, :list, required: true)
  attr(:storage_locations, :list, required: true)
  attr(:page, :integer, default: 1)
  attr(:per_page, :integer, default: 12)
  attr(:total_count, :integer, default: 0)
  attr(:total_pages, :integer, default: 1)

  def inventory_tab(assigns) do
    # Calculate counts for bulk actions
    expired_count =
      Enum.count(assigns.inventory_entries, fn e ->
        e.use_by_date && Date.compare(e.use_by_date, Date.utc_today()) == :lt &&
          e.status == :available
      end)

    available_count = Enum.count(assigns.inventory_entries, fn e -> e.status == :available end)
    assigns = assign(assigns, :expired_count, expired_count)
    assigns = assign(assigns, :available_count, available_count)

    ~H"""
    <div class="flex flex-wrap justify-between items-center gap-4 mb-6">
      <div class="flex flex-wrap gap-2">
        <%= if @expired_count > 0 do %>
          <.button
            phx-click="bulk_mark_expired"
            class="btn-warning btn-sm"
            title="Mark all past-date items as expired"
          >
            <svg class="w-4 h-4 inline mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            Mark {@expired_count} Expired
          </.button>
        <% end %>
        <%= if @available_count > 0 do %>
          <.button
            phx-click="bulk_consume_available"
            data-confirm="Mark all available items as consumed?"
            class="btn-info btn-sm"
            title="Mark all available items as consumed"
          >
            <svg class="w-4 h-4 inline mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M5 13l4 4L19 7"
              />
            </svg>
            Consume All ({@available_count})
          </.button>
        <% end %>
      </div>
      <.button
        phx-click="new_entry"
        class="btn-success"
      >
        <svg
          class="w-5 h-5 inline mr-2"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 6v6m0 0v6m0-6h6m-6 0H6"
          />
        </svg>
        New Entry
      </.button>
    </div>

    <%= if @show_form == :entry do %>
      <div class="mb-6 bg-success/5 border border-success/20 rounded-xl p-6">
        <h3 class="text-lg font-semibold text-base-content mb-4">Add New Inventory Entry</h3>
        <.form for={@form} id="entry-form" phx-submit="save_entry">
          <div class="space-y-4">
            <.input
              field={@form[:grocery_item_id]}
              type="select"
              label="Grocery Item"
              required
              options={Enum.map(@items, fn i -> {i.name, i.id} end)}
            />
            <.input
              field={@form[:storage_location_id]}
              type="select"
              label="Storage Location"
              required
              options={Enum.map(@storage_locations, fn l -> {l.name, l.id} end)}
            />
            <.input field={@form[:quantity]} type="number" label="Quantity" required step="0.01" />
            <.input field={@form[:purchase_price]} type="number" label="Price" step="0.01" />
            <.input
              field={@form[:unit]}
              type="text"
              label="Unit"
              required
              placeholder="e.g., lbs, oz, liters"
            />
            <.input field={@form[:purchase_date]} type="date" label="Purchase Date" />
            <.input field={@form[:use_by_date]} type="date" label="Use By Date" />
            <.input field={@form[:notes]} type="textarea" label="Notes" />
            <.input
              field={@form[:status]}
              type="select"
              label="Status"
              options={[
                {"Available", "available"},
                {"Reserved", "reserved"},
                {"Expired", "expired"},
                {"Consumed", "consumed"}
              ]}
              value="available"
            />

            <div class="flex gap-2 justify-end">
              <.button
                type="button"
                phx-click="cancel_form"
                class="btn-ghost"
              >
                Cancel
              </.button>
              <.button
                type="submit"
                class="btn-success"
              >
                Save Entry
              </.button>
            </div>
          </div>
        </.form>
      </div>
    <% end %>

    <div class="space-y-3">
      <div
        :for={entry <- @inventory_entries}
        class="flex items-center justify-between p-5 bg-base-200/30 rounded-xl border border-base-200 hover:border-success/30 hover:bg-success/5 transition"
      >
        <div class="flex items-center gap-4 flex-1">
          <div class="w-12 h-12 bg-success/10 rounded-lg flex items-center justify-center flex-shrink-0">
            <svg
              class="w-6 h-6 text-success"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
              />
            </svg>
          </div>
          <div class="flex-1">
            <div class="font-semibold text-base-content text-lg">
              {entry.grocery_item.name}
            </div>
            <div class="text-sm text-base-content/60 mt-1">
              {entry.quantity} {entry.unit}
              <%= if entry.storage_location do %>
                · Stored in: {entry.storage_location.name}
              <% end %>
            </div>
            <div
              :if={entry.use_by_date}
              class="text-sm text-base-content/60 mt-1 flex items-center gap-1"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              Expires: {Calendar.strftime(entry.use_by_date, "%B %d, %Y")}
            </div>
            <div :if={entry.notes} class="text-sm text-base-content/60 mt-1">{entry.notes}</div>
          </div>
        </div>
        <div class="flex items-center gap-3">
          <span class={[
            "badge badge-sm capitalize",
            case entry.status do
              :available -> "badge-success"
              :reserved -> "badge-info"
              :expired -> "badge-error"
              :consumed -> "badge-ghost"
            end
          ]}>
            {entry.status}
          </span>
          <.button
            phx-click="consume_entry"
            phx-value-id={entry.id}
            class="btn-ghost btn-sm text-info"
            title="Mark as Consumed"
          >
            Consume
          </.button>
          <.button
            phx-click="expire_entry"
            phx-value-id={entry.id}
            class="btn-ghost btn-sm text-warning"
            title="Mark as Expired"
          >
            Expire
          </.button>
          <.button
            phx-click="delete_entry"
            phx-value-id={entry.id}
            class="btn-error btn-outline btn-sm"
          >
            Delete
          </.button>
        </div>
      </div>

      <div :if={@inventory_entries == []} class="text-center py-16">
        <svg
          class="w-16 h-16 text-base-content/20 mx-auto mb-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
          />
        </svg>
        <p class="text-base-content/50 font-medium">No inventory entries yet</p>
      </div>
    </div>

    <%= if @total_pages > 1 do %>
      <div class="mt-8 flex items-center justify-between">
        <p class="text-sm text-base-content/60">
          Showing {(@page - 1) * @per_page + 1}-{min(@page * @per_page, @total_count)} of {@total_count} entries
        </p>
        <div class="join">
          <button
            class="join-item btn btn-sm"
            phx-click="inventory_page"
            phx-value-page={@page - 1}
            disabled={@page <= 1}
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15 19l-7-7 7-7"
              />
            </svg>
          </button>
          <%= for page_num <- max(1, @page - 2)..min(@total_pages, @page + 2) do %>
            <button
              class={"join-item btn btn-sm #{if page_num == @page, do: "btn-primary", else: ""}"}
              phx-click="inventory_page"
              phx-value-page={page_num}
            >
              {page_num}
            </button>
          <% end %>
          <button
            class="join-item btn btn-sm"
            phx-click="inventory_page"
            phx-value-page={@page + 1}
            disabled={@page >= @total_pages}
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>
      </div>
    <% end %>
    """
  end
end
