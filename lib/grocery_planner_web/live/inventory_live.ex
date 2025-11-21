defmodule GroceryPlannerWeb.InventoryLive do
  use GroceryPlannerWeb, :live_view

  on_mount {GroceryPlannerWeb.Auth, :require_authenticated_user}

  alias GroceryPlanner.Inventory.{GroceryItem, InventoryEntry}

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
          <div>
            <h1 class="text-4xl font-bold text-gray-900">Inventory Management</h1>
            <p class="mt-2 text-lg text-gray-600">
              Manage your grocery items and track what's in stock
            </p>
          </div>
        </div>

        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
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
                />
              <% "inventory" -> %>
                <.inventory_tab
                  inventory_entries={@inventory_entries}
                  show_form={@show_form}
                  form={@form}
                  items={@items}
                  storage_locations={@storage_locations}
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

  attr :active_tab, :string, required: true

  defp tab_navigation(assigns) do
    ~H"""
    <div class="border-b border-gray-200 bg-gray-50">
      <nav class="flex">
        <button
          phx-click="change_tab"
          phx-value-tab="items"
          class={[
            "flex-1 px-6 py-4 text-sm font-medium transition",
            if(@active_tab == "items",
              do: "bg-white border-b-2 border-blue-500 text-blue-600",
              else: "text-gray-600 hover:text-gray-900 hover:bg-white/50"
            )
          ]}
        >
          <svg class="w-5 h-5 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"
            />
          </svg>
          Grocery Items
        </button>
        <button
          phx-click="change_tab"
          phx-value-tab="inventory"
          class={[
            "flex-1 px-6 py-4 text-sm font-medium transition",
            if(@active_tab == "inventory",
              do: "bg-white border-b-2 border-blue-500 text-blue-600",
              else: "text-gray-600 hover:text-gray-900 hover:bg-white/50"
            )
          ]}
        >
          <svg class="w-5 h-5 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
            />
          </svg>
          Current Inventory
        </button>
        <button
          phx-click="change_tab"
          phx-value-tab="categories"
          class={[
            "flex-1 px-6 py-4 text-sm font-medium transition",
            if(@active_tab == "categories",
              do: "bg-white border-b-2 border-blue-500 text-blue-600",
              else: "text-gray-600 hover:text-gray-900 hover:bg-white/50"
            )
          ]}
        >
          <svg class="w-5 h-5 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
            />
          </svg>
          Categories
        </button>
        <button
          phx-click="change_tab"
          phx-value-tab="locations"
          class={[
            "flex-1 px-6 py-4 text-sm font-medium transition",
            if(@active_tab == "locations",
              do: "bg-white border-b-2 border-blue-500 text-blue-600",
              else: "text-gray-600 hover:text-gray-900 hover:bg-white/50"
            )
          ]}
        >
          <svg class="w-5 h-5 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
            />
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
            />
          </svg>
          Storage Locations
        </button>
        <button
          phx-click="change_tab"
          phx-value-tab="tags"
          class={[
            "flex-1 px-6 py-4 text-sm font-medium transition",
            if(@active_tab == "tags",
              do: "bg-white border-b-2 border-blue-500 text-blue-600",
              else: "text-gray-600 hover:text-gray-900 hover:bg-white/50"
            )
          ]}
        >
          <svg class="w-5 h-5 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
            />
          </svg>
          Tags
        </button>
      </nav>
    </div>
    """
  end

  attr :items, :list, required: true
  attr :tags, :list, required: true
  attr :filter_tag_ids, :list, required: true
  attr :show_form, :atom, default: nil
  attr :form, :any, default: nil
  attr :editing_id, :any, default: nil
  attr :managing_tags_for, :any, default: nil
  attr :categories, :list, required: true

  defp items_tab(assigns) do
    ~H"""
    <div class="flex justify-between items-start mb-6">
      <div class="flex flex-col gap-2">
        <%= if @tags != [] do %>
          <div class="flex items-center gap-2">
            <span class="text-sm font-medium text-gray-700">Filter by tags:</span>
            <%= if @filter_tag_ids != [] do %>
              <.button
                phx-click="clear_tag_filters"
                class="px-2 py-1 text-xs bg-gray-200 text-gray-700 rounded hover:bg-gray-300 transition font-medium"
              >
                Clear all
              </.button>
            <% end %>
          </div>
          <div class="flex flex-wrap gap-2">
            <.button
              :for={tag <- @tags}
              phx-click="toggle_tag_filter"
              phx-value-tag-id={tag.id}
              class={"px-3 py-1 rounded-lg transition text-sm font-medium inline-flex items-center gap-2 #{if tag.id in @filter_tag_ids, do: "ring-2 ring-offset-1", else: "opacity-60 hover:opacity-100"}"}
              style={
                if(tag.id in @filter_tag_ids,
                  do: "background-color: #{tag.color}; color: white; ring-color: #{tag.color}",
                  else: "background-color: #{tag.color}20; color: #{tag.color}"
                )
              }
            >
              {tag.name}
              <%= if tag.id in @filter_tag_ids do %>
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M5 13l4 4L19 7"
                  />
                </svg>
              <% end %>
            </.button>
          </div>
        <% end %>
      </div>

      <.button
        phx-click="new_item"
        class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition font-medium"
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
        New Item
      </.button>
    </div>

    <%= if @show_form == :item do %>
      <div class="mb-6 bg-blue-50 border border-blue-200 rounded-xl p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">
          {if @editing_id, do: "Edit Grocery Item", else: "Add New Grocery Item"}
        </h3>
        <.form for={@form} id="item-form" phx-submit="save_item">
          <div class="space-y-4">
            <.input field={@form[:name]} type="text" label="Name" required />
            <.input field={@form[:description]} type="text" label="Description" />
            <.input
              field={@form[:default_unit]}
              type="text"
              label="Default Unit"
              placeholder="e.g., lbs, oz, liters"
            />
            <.input field={@form[:barcode]} type="text" label="Barcode (optional)" />
            <.input
              field={@form[:category_id]}
              type="select"
              label="Category"
              options={[{"None", nil}] ++ Enum.map(@categories, fn c -> {c.name, c.id} end)}
            />

            <div class="flex gap-2 justify-end">
              <.button
                type="button"
                phx-click="cancel_form"
                class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition"
              >
                Cancel
              </.button>
              <.button
                type="submit"
                class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
              >
                Save Item
              </.button>
            </div>
          </div>
        </.form>
      </div>
    <% end %>

    <%= if @managing_tags_for do %>
      <% item = Enum.find(@items, &(&1.id == @managing_tags_for)) %>
      <% item_tag_ids = Enum.map(item.tags, & &1.id) %>

      <div class="mb-6 bg-pink-50 border border-pink-200 rounded-xl p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">
          Manage Tags for {item.name}
        </h3>

        <div class="space-y-3">
          <div
            :for={tag <- @tags}
            class="flex items-center justify-between p-3 bg-white rounded-lg border border-gray-200"
          >
            <div class="flex items-center gap-3">
              <div
                class="w-8 h-8 rounded flex items-center justify-center"
                style={"background-color: #{tag.color}20"}
              >
                <svg
                  class="w-4 h-4"
                  style={"color: #{tag.color}"}
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
                  />
                </svg>
              </div>
              <div>
                <div class="font-medium text-gray-900">{tag.name}</div>
                <div :if={tag.description} class="text-xs text-gray-500">{tag.description}</div>
              </div>
            </div>

            <%= if tag.id in item_tag_ids do %>
              <.button
                phx-click="remove_tag_from_item"
                phx-value-item-id={item.id}
                phx-value-tag-id={tag.id}
                class="px-3 py-1 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition text-sm font-medium"
              >
                Remove
              </.button>
            <% else %>
              <.button
                phx-click="add_tag_to_item"
                phx-value-item-id={item.id}
                phx-value-tag-id={tag.id}
                class="px-3 py-1 bg-green-100 text-green-700 rounded-lg hover:bg-green-200 transition text-sm font-medium"
              >
                Add
              </.button>
            <% end %>
          </div>

          <div :if={@tags == []} class="text-center py-8 text-gray-500">
            No tags available. Create tags in the Tags tab first.
          </div>
        </div>

        <div class="flex justify-end mt-4">
          <.button
            phx-click="cancel_tag_management"
            class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition"
          >
            Done
          </.button>
        </div>
      </div>
    <% end %>

    <div class="space-y-3">
      <div
        :for={item <- @items}
        class="flex items-center justify-between p-5 bg-gray-50 rounded-xl border border-gray-200 hover:border-blue-300 hover:bg-blue-50/30 transition"
      >
        <div class="flex items-center gap-4 flex-1">
          <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center flex-shrink-0">
            <svg
              class="w-6 h-6 text-blue-600"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"
              />
            </svg>
          </div>
          <div class="flex-1">
            <div class="font-semibold text-gray-900">{item.name}</div>
            <div :if={item.description} class="text-sm text-gray-600 mt-1">
              {item.description}
            </div>
            <div :if={item.default_unit} class="text-sm text-blue-600 mt-1">
              Default: {item.default_unit}
            </div>
            <div :if={item.tags != []} class="flex flex-wrap gap-1 mt-2">
              <span
                :for={tag <- item.tags}
                class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium"
                style={"background-color: #{tag.color}20; color: #{tag.color}"}
              >
                {tag.name}
              </span>
            </div>
          </div>
        </div>
        <div class="flex gap-2">
          <.button
            phx-click="manage_tags"
            phx-value-id={item.id}
            class="px-4 py-2 bg-pink-100 text-pink-700 rounded-lg hover:bg-pink-200 transition text-sm font-medium"
            title="Manage Tags"
          >
            <svg
              class="w-4 h-4 inline"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
              />
            </svg>
          </.button>
          <.button
            phx-click="edit_item"
            phx-value-id={item.id}
            class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition text-sm font-medium"
          >
            Edit
          </.button>
          <.button
            phx-click="delete_item"
            phx-value-id={item.id}
            class="px-4 py-2 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition text-sm font-medium"
          >
            Delete
          </.button>
        </div>
      </div>

      <div :if={@items == []} class="text-center py-16">
        <svg
          class="w-16 h-16 text-gray-300 mx-auto mb-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"
          />
        </svg>
        <p class="text-gray-500 font-medium">No grocery items yet</p>
        <p class="text-gray-400 text-sm mt-1">Click "New Item" to get started</p>
      </div>
    </div>
    """
  end

  attr :inventory_entries, :list, required: true
  attr :show_form, :atom, default: nil
  attr :form, :any, default: nil
  attr :items, :list, required: true
  attr :storage_locations, :list, required: true

  defp inventory_tab(assigns) do
    ~H"""
    <div class="flex justify-end mb-6">
      <.button
        phx-click="new_entry"
        class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition font-medium"
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
      <div class="mb-6 bg-green-50 border border-green-200 rounded-xl p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Add New Inventory Entry</h3>
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
                class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition"
              >
                Cancel
              </.button>
              <.button
                type="submit"
                class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition"
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
        class="flex items-center justify-between p-5 bg-gray-50 rounded-xl border border-gray-200 hover:border-green-300 hover:bg-green-50/30 transition"
      >
        <div class="flex items-center gap-4 flex-1">
          <div class="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center flex-shrink-0">
            <svg
              class="w-6 h-6 text-green-600"
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
            <div class="font-semibold text-gray-900 text-lg">
              {entry.grocery_item.name}
            </div>
            <div class="text-sm text-gray-600 mt-1">
              {entry.quantity} {entry.unit}
              <%= if entry.storage_location do %>
                · Stored in: {entry.storage_location.name}
              <% end %>
            </div>
            <div
              :if={entry.use_by_date}
              class="text-sm text-gray-600 mt-1 flex items-center gap-1"
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
            <div :if={entry.notes} class="text-sm text-gray-600 mt-1">{entry.notes}</div>
          </div>
        </div>
        <div class="flex items-center gap-3">
          <span class={[
            "px-3 py-1 rounded-full text-sm font-medium capitalize",
            case entry.status do
              :available -> "bg-green-100 text-green-800"
              :reserved -> "bg-blue-100 text-blue-800"
              :expired -> "bg-red-100 text-red-800"
              :consumed -> "bg-gray-100 text-gray-800"
            end
          ]}>
            {entry.status}
          </span>
          <.button
            phx-click="delete_entry"
            phx-value-id={entry.id}
            class="px-4 py-2 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition text-sm font-medium"
          >
            Delete
          </.button>
        </div>
      </div>

      <div :if={@inventory_entries == []} class="text-center py-16">
        <svg
          class="w-16 h-16 text-gray-300 mx-auto mb-4"
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
        <p class="text-gray-500 font-medium">No inventory entries yet</p>
      </div>
    </div>
    """
  end

  attr :categories, :list, required: true
  attr :show_form, :atom, default: nil
  attr :form, :any, default: nil

  defp categories_tab(assigns) do
    ~H"""
    <div class="flex justify-end mb-6">
      <.button
        phx-click="new_category"
        class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition font-medium"
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
        New Category
      </.button>
    </div>

    <%= if @show_form == :category do %>
      <div class="mb-6 bg-purple-50 border border-purple-200 rounded-xl p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Add New Category</h3>
        <.form for={@form} id="category-form" phx-submit="save_category">
          <div class="space-y-4">
            <.input field={@form[:name]} type="text" label="Name" required />
            <.input field={@form[:icon]} type="text" label="Icon" />
            <.input field={@form[:sort_order]} type="number" label="Sort Order" />

            <div class="flex gap-2 justify-end">
              <.button
                type="button"
                phx-click="cancel_form"
                class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition"
              >
                Cancel
              </.button>
              <.button
                type="submit"
                class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition"
              >
                Save Category
              </.button>
            </div>
          </div>
        </.form>
      </div>
    <% end %>

    <div class="space-y-3">
      <div
        :for={category <- @categories}
        class="flex items-center justify-between p-5 bg-gray-50 rounded-xl border border-gray-200 hover:border-purple-300 hover:bg-purple-50/30 transition"
      >
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center flex-shrink-0">
            <svg
              class="w-6 h-6 text-purple-600"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
              />
            </svg>
          </div>
          <div>
            <div class="font-semibold text-gray-900">{category.name}</div>
            <div :if={category.icon} class="text-sm text-purple-600 mt-1">
              Icon: {category.icon}
            </div>
          </div>
        </div>
        <.button
          phx-click="delete_category"
          phx-value-id={category.id}
          class="px-4 py-2 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition text-sm font-medium"
        >
          Delete
        </.button>
      </div>

      <div :if={@categories == []} class="text-center py-16">
        <svg
          class="w-16 h-16 text-gray-300 mx-auto mb-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
          />
        </svg>
        <p class="text-gray-500 font-medium">No categories yet</p>
      </div>
    </div>
    """
  end

  attr :storage_locations, :list, required: true
  attr :show_form, :atom, default: nil
  attr :form, :any, default: nil

  defp locations_tab(assigns) do
    ~H"""
    <div class="flex justify-end mb-6">
      <.button
        phx-click="new_location"
        class="px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition font-medium"
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
        New Location
      </.button>
    </div>

    <%= if @show_form == :location do %>
      <div class="mb-6 bg-orange-50 border border-orange-200 rounded-xl p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Add New Storage Location</h3>
        <.form for={@form} id="location-form" phx-submit="save_location">
          <div class="space-y-4">
            <.input field={@form[:name]} type="text" label="Name" required />
            <.input
              field={@form[:temperature_zone]}
              type="select"
              label="Temperature Zone"
              options={[
                {"Frozen", "frozen"},
                {"Cold (Refrigerated)", "cold"},
                {"Cool", "cool"},
                {"Room Temperature", "room_temp"}
              ]}
            />

            <div class="flex gap-2 justify-end">
              <.button
                type="button"
                phx-click="cancel_form"
                class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition"
              >
                Cancel
              </.button>
              <.button
                type="submit"
                class="px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition"
              >
                Save Location
              </.button>
            </div>
          </div>
        </.form>
      </div>
    <% end %>

    <div class="space-y-3">
      <div
        :for={location <- @storage_locations}
        class="flex items-center justify-between p-5 bg-gray-50 rounded-xl border border-gray-200 hover:border-orange-300 hover:bg-orange-50/30 transition"
      >
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center flex-shrink-0">
            <svg
              class="w-6 h-6 text-orange-600"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
              />
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
              />
            </svg>
          </div>
          <div>
            <div class="font-semibold text-gray-900">{location.name}</div>
            <div
              :if={location.temperature_zone}
              class="text-sm text-orange-600 mt-1 capitalize"
            >
              Temperature: {location.temperature_zone}
            </div>
          </div>
        </div>
        <.button
          phx-click="delete_location"
          phx-value-id={location.id}
          class="px-4 py-2 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition text-sm font-medium"
        >
          Delete
        </.button>
      </div>

      <div :if={@storage_locations == []} class="text-center py-16">
        <svg
          class="w-16 h-16 text-gray-300 mx-auto mb-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
          />
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
          />
        </svg>
        <p class="text-gray-500 font-medium">No storage locations yet</p>
      </div>
    </div>
    """
  end

  attr :tags, :list, required: true
  attr :show_form, :atom, default: nil
  attr :form, :any, default: nil
  attr :editing_id, :any, default: nil

  defp tags_tab(assigns) do
    ~H"""
    <div class="flex justify-end mb-6">
      <.button
        phx-click="new_tag"
        class="px-4 py-2 bg-pink-600 text-white rounded-lg hover:bg-pink-700 transition font-medium"
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
        New Tag
      </.button>
    </div>

    <%= if @show_form == :tag do %>
      <div class="mb-6 bg-pink-50 border border-pink-200 rounded-xl p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">
          {if @editing_id, do: "Edit Tag", else: "Add New Tag"}
        </h3>
        <.form for={@form} id="tag-form" phx-submit="save_tag">
          <div class="space-y-4">
            <.input field={@form[:name]} type="text" label="Name" required />
            <.input
              field={@form[:color]}
              type="text"
              label="Color (hex code)"
              placeholder="#3B82F6"
            />
            <.input
              field={@form[:description]}
              type="textarea"
              label="Description (optional)"
            />

            <div class="flex gap-2 justify-end">
              <.button
                type="button"
                phx-click="cancel_form"
                class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition"
              >
                Cancel
              </.button>
              <.button
                type="submit"
                class="px-4 py-2 bg-pink-600 text-white rounded-lg hover:bg-pink-700 transition"
              >
                Save Tag
              </.button>
            </div>
          </div>
        </.form>
      </div>
    <% end %>

    <div class="space-y-3">
      <div
        :for={tag <- @tags}
        class="flex items-center justify-between p-5 bg-gray-50 rounded-xl border border-gray-200 hover:border-pink-300 hover:bg-pink-50/30 transition"
      >
        <div class="flex items-center gap-4">
          <div
            class="w-12 h-12 rounded-lg flex items-center justify-center flex-shrink-0"
            style={"background-color: #{tag.color}20"}
          >
            <svg
              class="w-6 h-6"
              style={"color: #{tag.color}"}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
              />
            </svg>
          </div>
          <div>
            <div class="font-semibold text-gray-900">{tag.name}</div>
            <div :if={tag.description} class="text-sm text-gray-600 mt-1">
              {tag.description}
            </div>
          </div>
        </div>
        <div class="flex gap-2">
          <.button
            phx-click="edit_tag"
            phx-value-id={tag.id}
            class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition text-sm font-medium"
          >
            Edit
          </.button>
          <.button
            phx-click="delete_tag"
            phx-value-id={tag.id}
            class="px-4 py-2 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition text-sm font-medium"
          >
            Delete
          </.button>
        </div>
      </div>

      <div :if={@tags == []} class="text-center py-16">
        <svg
          class="w-16 h-16 text-gray-300 mx-auto mb-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
          />
        </svg>
        <p class="text-gray-500 font-medium">No tags yet</p>
        <p class="text-gray-400 text-sm mt-1">Create tags to organize your grocery items</p>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:current_scope, socket.assigns.current_account)
      |> assign(:active_tab, "items")
      |> assign(:show_form, nil)
      |> assign(:form, nil)
      |> assign(:editing_id, nil)
      |> assign(:managing_tags_for, nil)
      |> assign(:show_tag_modal, false)
      |> assign(:filter_tag_ids, [])
      |> load_data()

    {:ok, socket}
  end

  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("new_item", _, socket) do
    {:noreply, assign(socket, show_form: :item, form: to_form(%{}, as: :item), editing_id: nil)}
  end

  def handle_event("new_location", _, socket) do
    {:noreply, assign(socket, show_form: :location, form: to_form(%{}, as: :location))}
  end

  def handle_event("new_category", _, socket) do
    {:noreply, assign(socket, show_form: :category, form: to_form(%{}, as: :category))}
  end

  def handle_event("new_tag", _, socket) do
    {:noreply, assign(socket, show_form: :tag, form: to_form(%{}, as: :tag), editing_id: nil)}
  end

  def handle_event("new_entry", _, socket) do
    {:noreply, assign(socket, show_form: :entry, form: to_form(%{}, as: :entry))}
  end

  def handle_event("cancel_form", _, socket) do
    {:noreply, assign(socket, show_form: nil, form: nil, editing_id: nil)}
  end

  def handle_event("save_location", %{"location" => params}, socket) do
    account_id = socket.assigns.current_account.id

    case GroceryPlanner.Inventory.create_storage_location!(
           account_id,
           params,
           authorize?: false,
           tenant: account_id
         ) do
      location when is_struct(location) ->
        socket =
          socket
          |> load_data()
          |> assign(show_form: nil, form: nil)
          |> put_flash(:info, "Storage location created successfully")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create storage location")}
    end
  end

  def handle_event("save_category", %{"category" => params}, socket) do
    account_id = socket.assigns.current_account.id

    case GroceryPlanner.Inventory.create_category!(
           account_id,
           params,
           authorize?: false,
           tenant: account_id
         ) do
      category when is_struct(category) ->
        socket =
          socket
          |> load_data()
          |> assign(show_form: nil, form: nil)
          |> put_flash(:info, "Category created successfully")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create category")}
    end
  end

  def handle_event("save_item", %{"item" => params}, socket) do
    account_id = socket.assigns.current_account.id

    case GroceryPlanner.Inventory.create_grocery_item!(
           account_id,
           params,
           authorize?: false,
           tenant: account_id
         ) do
      item when is_struct(item) ->
        socket =
          socket
          |> load_data()
          |> assign(show_form: nil, form: nil, editing_id: nil)
          |> put_flash(:info, "Grocery item created successfully")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create grocery item")}
    end
  end

  def handle_event("save_entry", %{"entry" => params}, socket) do
    account_id = socket.assigns.current_account.id
    grocery_item_id = params["grocery_item_id"]

    case GroceryPlanner.Inventory.create_inventory_entry!(
           account_id,
           grocery_item_id,
           params,
           authorize?: false,
           tenant: account_id
         ) do
      entry when is_struct(entry) ->
        socket =
          socket
          |> load_data()
          |> assign(show_form: nil, form: nil)
          |> put_flash(:info, "Inventory entry created successfully")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create inventory entry")}
    end
  end

  def handle_event("delete_item", %{"id" => id}, socket) do
    case GroceryPlanner.Inventory.get_grocery_item(id,
           actor: socket.assigns.current_user,
           tenant: socket.assigns.current_account.id
         ) do
      {:ok, item} ->
        result = GroceryPlanner.Inventory.destroy_grocery_item(item,
          actor: socket.assigns.current_user,
          tenant: socket.assigns.current_account.id
        )

        case result do
          {:ok, _} ->
            socket =
              socket
              |> load_data()
              |> put_flash(:info, "Item deleted successfully")

            {:noreply, socket}

          :ok ->
            socket =
              socket
              |> load_data()
              |> put_flash(:info, "Item deleted successfully")

            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete item")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Item not found")}
    end
  end

  def handle_event("delete_category", %{"id" => id}, socket) do
    case GroceryPlanner.Inventory.get_category(id,
           actor: socket.assigns.current_user,
           tenant: socket.assigns.current_account.id
         ) do
      {:ok, category} ->
        result = GroceryPlanner.Inventory.destroy_category(category,
          actor: socket.assigns.current_user,
          tenant: socket.assigns.current_account.id
        )

        case result do
          {:ok, _} ->
            socket =
              socket
              |> load_data()
              |> put_flash(:info, "Category deleted successfully")

            {:noreply, socket}

          :ok ->
            socket =
              socket
              |> load_data()
              |> put_flash(:info, "Category deleted successfully")

            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete category")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Category not found")}
    end
  end

  def handle_event("delete_location", %{"id" => id}, socket) do
    case GroceryPlanner.Inventory.get_storage_location(id,
           actor: socket.assigns.current_user,
           tenant: socket.assigns.current_account.id
         ) do
      {:ok, location} ->
        result = GroceryPlanner.Inventory.destroy_storage_location(location,
          actor: socket.assigns.current_user,
          tenant: socket.assigns.current_account.id
        )

        case result do
          {:ok, _} ->
            socket =
              socket
              |> load_data()
              |> put_flash(:info, "Storage location deleted successfully")

            {:noreply, socket}

          :ok ->
            socket =
              socket
              |> load_data()
              |> put_flash(:info, "Storage location deleted successfully")

            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete storage location")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Storage location not found")}
    end
  end

  def handle_event("save_tag", %{"tag" => params}, socket) do
    account_id = socket.assigns.current_account.id

    result =
      if socket.assigns.editing_id do
        case GroceryPlanner.Inventory.get_grocery_item_tag(
               socket.assigns.editing_id,
               authorize?: false,
               tenant: account_id
             ) do
          {:ok, tag} ->
            GroceryPlanner.Inventory.update_grocery_item_tag(
              tag,
              params,
              authorize?: false
            )

          error ->
            error
        end
      else
        GroceryPlanner.Inventory.create_grocery_item_tag(
          account_id,
          params,
          authorize?: false,
          tenant: account_id
        )
      end

    case result do
      {:ok, _tag} ->
        socket =
          socket
          |> load_data()
          |> assign(show_form: nil, form: nil, editing_id: nil)
          |> put_flash(
            :info,
            if(socket.assigns.editing_id,
              do: "Tag updated successfully",
              else: "Tag created successfully"
            )
          )

        {:noreply, socket}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           if(socket.assigns.editing_id, do: "Failed to update tag", else: "Failed to create tag")
         )}
    end
  end

  def handle_event("edit_tag", %{"id" => id}, socket) do
    case GroceryPlanner.Inventory.get_grocery_item_tag(
           id,
           authorize?: false,
           tenant: socket.assigns.current_account.id
         ) do
      {:ok, tag} ->
        form =
          to_form(
            %{
              "name" => tag.name,
              "color" => tag.color,
              "description" => tag.description
            },
            as: :tag
          )

        {:noreply, assign(socket, show_form: :tag, form: form, editing_id: id)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Tag not found")}
    end
  end

  def handle_event("delete_tag", %{"id" => id}, socket) do
    case GroceryPlanner.Inventory.get_grocery_item_tag(
           id,
           authorize?: false,
           tenant: socket.assigns.current_account.id
         ) do
      {:ok, tag} ->
        result = GroceryPlanner.Inventory.destroy_grocery_item_tag(tag, authorize?: false)

        case result do
          {:ok, _} ->
            socket =
              socket
              |> load_data()
              |> put_flash(:info, "Tag deleted successfully")

            {:noreply, socket}

          :ok ->
            socket =
              socket
              |> load_data()
              |> put_flash(:info, "Tag deleted successfully")

            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete tag")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Tag not found")}
    end
  end

  def handle_event("delete_entry", %{"id" => id}, socket) do
    case GroceryPlanner.Inventory.get_inventory_entry(id,
           actor: socket.assigns.current_user,
           tenant: socket.assigns.current_account.id
         ) do
      {:ok, entry} ->
        result = GroceryPlanner.Inventory.destroy_inventory_entry(entry,
          actor: socket.assigns.current_user,
          tenant: socket.assigns.current_account.id
        )

        case result do
          {:ok, _} ->
            socket =
              socket
              |> load_data()
              |> put_flash(:info, "Inventory entry deleted successfully")

            {:noreply, socket}

          :ok ->
            socket =
              socket
              |> load_data()
              |> put_flash(:info, "Inventory entry deleted successfully")

            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete inventory entry")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Inventory entry not found")}
    end
  end

  defp load_data(socket) do
    import Ash.Query, only: [filter: 2]
    account_id = socket.assigns.current_account.id
    user = socket.assigns.current_user

    items_query = GroceryItem |> Ash.Query.load(:tags)

    items_query =
      if socket.assigns[:filter_tag_ids] && socket.assigns.filter_tag_ids != [] do
        Enum.reduce(socket.assigns.filter_tag_ids, items_query, fn filter_tag_id, query ->
          filter(query, exists(tags, id == ^filter_tag_id))
        end)
      else
        items_query
      end

    {:ok, items} = GroceryPlanner.Inventory.list_grocery_items(actor: user, tenant: account_id, query: items_query)

    {:ok, categories} = GroceryPlanner.Inventory.list_categories(actor: user, tenant: account_id)
    {:ok, locations} = GroceryPlanner.Inventory.list_storage_locations(actor: user, tenant: account_id)
    {:ok, tags} = GroceryPlanner.Inventory.list_grocery_item_tags(authorize?: false, tenant: account_id)

    {:ok, entries} = GroceryPlanner.Inventory.list_inventory_entries(
      actor: user,
      tenant: account_id,
      query: InventoryEntry |> Ash.Query.load([:grocery_item, :storage_location])
    )

    socket
    |> assign(:items, items)
    |> assign(:categories, categories)
    |> assign(:storage_locations, locations)
    |> assign(:inventory_entries, entries)
    |> assign(:tags, tags)
  end
end
