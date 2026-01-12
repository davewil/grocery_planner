defmodule GroceryPlannerWeb.InventoryLive do
  use GroceryPlannerWeb, :live_view

  on_mount({GroceryPlannerWeb.Auth, :require_authenticated_user})

  alias GroceryPlanner.Inventory.{GroceryItem, InventoryEntry}
  alias GroceryPlanner.AiClient

  require Ash.Query

  @inventory_per_page 12

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
            <h1 class="text-4xl font-bold text-base-content">Inventory Management</h1>
            <p class="mt-2 text-lg text-base-content/70">
              Manage your grocery items and track what's in stock
            </p>
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
                  <span class="truncate">Showing: {format_expiring_filter(@expiring_filter)}</span>
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

  attr(:active_tab, :string, required: true)

  defp tab_navigation(assigns) do
    ~H"""
    <div class="border-b border-base-200 bg-base-200/50">
      <nav class="flex">
        <button
          phx-click="change_tab"
          phx-value-tab="items"
          class={[
            "flex-1 px-6 py-4 text-sm font-medium transition",
            if(@active_tab == "items",
              do: "bg-base-100 border-b-2 border-primary text-primary",
              else: "text-base-content/60 hover:text-base-content hover:bg-base-100/50"
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
              do: "bg-base-100 border-b-2 border-primary text-primary",
              else: "text-base-content/60 hover:text-base-content hover:bg-base-100/50"
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
              do: "bg-base-100 border-b-2 border-primary text-primary",
              else: "text-base-content/60 hover:text-base-content hover:bg-base-100/50"
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
              do: "bg-base-100 border-b-2 border-primary text-primary",
              else: "text-base-content/60 hover:text-base-content hover:bg-base-100/50"
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
              do: "bg-base-100 border-b-2 border-primary text-primary",
              else: "text-base-content/60 hover:text-base-content hover:bg-base-100/50"
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

  attr(:items, :list, required: true)
  attr(:tags, :list, required: true)
  attr(:filter_tag_ids, :list, required: true)
  attr(:show_form, :atom, default: nil)
  attr(:form, :any, default: nil)
  attr(:editing_id, :any, default: nil)
  attr(:managing_tags_for, :any, default: nil)
  attr(:categories, :list, required: true)
  attr(:selected_tag_ids, :list, default: [])

  defp items_tab(assigns) do
    ~H"""
    <div class="flex justify-between items-start mb-6">
      <div class="flex flex-col gap-2">
        <%= if @tags != [] do %>
          <div class="flex items-center gap-2">
            <span class="text-sm font-medium text-base-content/80">Filter by tags:</span>
            <%= if @filter_tag_ids != [] do %>
              <.button
                phx-click="clear_tag_filters"
                class="btn-ghost btn-xs"
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
        class="btn-primary"
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

    <.modal
      :if={@show_form == :item}
      id="item-modal"
      show={true}
      on_cancel={JS.push("cancel_form")}
    >
      <h3 class="text-lg font-semibold text-base-content mb-4">
        {if @editing_id, do: "Edit Grocery Item", else: "Add New Grocery Item"}
      </h3>
      <.form for={@form} id="item-form" phx-change="validate_item" phx-submit="save_item">
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

          <div class="flex items-end gap-2">
            <div class="flex-1">
              <.input
                field={@form[:category_id]}
                type="select"
                label="Category"
                options={[{"None", nil}] ++ Enum.map(@categories, fn c -> {c.name, c.id} end)}
              />
            </div>
            <button
              type="button"
              phx-click="suggest_category"
              class="btn btn-secondary btn-outline mb-[2px]"
              title="Auto-detect category with AI"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
                class="w-5 h-5"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 1c3.866 0 7 1.789 7 4 0 1.657-1.745 3.104-4.363 3.655C12.449 8.924 12 9.208 12 9.5v1a.5.5 0 01-1 0v-1c0-.709.61-1.243 1.346-1.39C14.717 7.643 16 6.387 16 5c0-1.657-2.686-3-6-3S4 3.343 4 5c0 1.25 1.05 2.308 2.656 2.9.23.084.417.27.513.504l.5 1.25a.5.5 0 01-.928.372l-.5-1.25A1.47 1.47 0 005.5 8C3.12 7.258 2 5.753 2 5c0-2.211 3.134-4 7-4zm0 12a1 1 0 100 2 1 1 0 000-2z"
                  clip-rule="evenodd"
                />
              </svg>
              Suggest
            </button>
          </div>

          <%= if length(@tags) > 0 do %>
            <div class="space-y-2">
              <label class="block text-sm font-medium text-base-content/80">Tags</label>
              <div class="flex flex-wrap gap-2">
                <%= for tag <- @tags do %>
                  <label
                    class={"cursor-pointer px-3 py-2 rounded-lg transition text-sm font-medium inline-flex items-center gap-2 #{if tag.id in @selected_tag_ids, do: "ring-2 ring-offset-1", else: "opacity-60 hover:opacity-100"}"}
                    style={
                      if(tag.id in @selected_tag_ids,
                        do: "background-color: #{tag.color}; color: white; ring-color: #{tag.color}",
                        else: "background-color: #{tag.color}20; color: #{tag.color}"
                      )
                    }
                  >
                    <input
                      type="checkbox"
                      name="item[tag_ids][]"
                      value={tag.id}
                      checked={tag.id in @selected_tag_ids}
                      phx-click="toggle_form_tag"
                      phx-value-tag-id={tag.id}
                      class="sr-only"
                    />
                    {tag.name}
                    <%= if tag.id in @selected_tag_ids do %>
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M5 13l4 4L19 7"
                        />
                      </svg>
                    <% end %>
                  </label>
                <% end %>
              </div>
            </div>
          <% end %>

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
              class="btn-primary"
            >
              Save Item
            </.button>
          </div>
        </div>
      </.form>
    </.modal>

    <.modal
      :if={@managing_tags_for}
      id="manage-tags-modal"
      show={true}
      on_cancel={JS.push("cancel_tag_management")}
    >
      <% item = @managing_tags_for %>
      <% item_tag_ids = Enum.map(item.tags || [], & &1.id) %>

      <h3 class="text-lg font-semibold text-base-content mb-4">
        Manage Tags for {item.name}
      </h3>

      <div class="space-y-3">
        <div
          :for={tag <- @tags}
          class="flex items-center justify-between p-3 bg-base-100 rounded-lg border border-base-200"
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
              <div class="font-medium text-base-content">{tag.name}</div>
              <div :if={tag.description} class="text-xs text-base-content/50">{tag.description}</div>
            </div>
          </div>

          <%= if tag.id in item_tag_ids do %>
            <.button
              phx-click="remove_tag_from_item"
              phx-value-item-id={item.id}
              phx-value-tag-id={tag.id}
              class="btn-error btn-soft btn-sm"
            >
              Remove
            </.button>
          <% else %>
            <.button
              phx-click="add_tag_to_item"
              phx-value-item-id={item.id}
              phx-value-tag-id={tag.id}
              class="btn-success btn-soft btn-sm"
            >
              Add
            </.button>
          <% end %>
        </div>

        <div :if={@tags == []} class="text-center py-8 text-base-content/50">
          No tags available. Create tags in the Tags tab first.
        </div>
      </div>

      <div class="flex justify-end mt-4">
        <.button
          phx-click="cancel_tag_management"
          class="btn-ghost"
        >
          Done
        </.button>
      </div>
    </.modal>

    <div class="space-y-3">
      <div
        :for={item <- @items}
        class="flex items-center justify-between p-5 bg-base-200/30 rounded-xl border border-base-200 hover:border-primary/30 hover:bg-primary/5 transition"
      >
        <div class="flex items-center gap-4 flex-1">
          <div class="w-12 h-12 bg-primary/10 rounded-lg flex items-center justify-center flex-shrink-0">
            <svg
              class="w-6 h-6 text-primary"
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
            <div class="font-semibold text-base-content">{item.name}</div>
            <div :if={item.description} class="text-sm text-base-content/60 mt-1">
              {item.description}
            </div>
            <div :if={item.default_unit} class="text-sm text-primary mt-1">
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
            class="btn-ghost btn-sm text-secondary"
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
            class="btn-ghost btn-sm"
          >
            Edit
          </.button>
          <.button
            phx-click="delete_item"
            phx-value-id={item.id}
            class="btn-error btn-outline btn-sm"
          >
            Delete
          </.button>
        </div>
      </div>

      <div :if={@items == []} class="text-center py-16">
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
            d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"
          />
        </svg>
        <p class="text-base-content/50 font-medium">No grocery items yet</p>
        <p class="text-base-content/30 text-sm mt-1">Click "New Item" to get started</p>
      </div>
    </div>
    """
  end

  attr(:inventory_entries, :list, required: true)
  attr(:show_form, :atom, default: nil)
  attr(:form, :any, default: nil)
  attr(:items, :list, required: true)
  attr(:storage_locations, :list, required: true)
  attr(:page, :integer, default: 1)
  attr(:per_page, :integer, default: 12)
  attr(:total_count, :integer, default: 0)
  attr(:total_pages, :integer, default: 1)

  defp inventory_tab(assigns) do
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

  attr(:categories, :list, required: true)
  attr(:show_form, :atom, default: nil)
  attr(:form, :any, default: nil)

  defp categories_tab(assigns) do
    ~H"""
    <div class="flex justify-end mb-6">
      <.button
        phx-click="new_category"
        class="btn-secondary"
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
      <div class="mb-6 bg-secondary/5 border border-secondary/20 rounded-xl p-6">
        <h3 class="text-lg font-semibold text-base-content mb-4">Add New Category</h3>
        <.form for={@form} id="category-form" phx-submit="save_category">
          <div class="space-y-4">
            <.input field={@form[:name]} type="text" label="Name" required />
            <.input field={@form[:icon]} type="text" label="Icon" />
            <.input field={@form[:sort_order]} type="number" label="Sort Order" />

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
                class="btn-secondary"
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
        class="flex items-center justify-between p-5 bg-base-200/30 rounded-xl border border-base-200 hover:border-secondary/30 hover:bg-secondary/5 transition"
      >
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-secondary/10 rounded-lg flex items-center justify-center flex-shrink-0">
            <svg
              class="w-6 h-6 text-secondary"
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
            <div class="font-semibold text-base-content">{category.name}</div>
            <div :if={category.icon} class="text-sm text-secondary mt-1">
              Icon: {category.icon}
            </div>
          </div>
        </div>
        <.button
          phx-click="delete_category"
          phx-value-id={category.id}
          class="btn-error btn-outline btn-sm"
        >
          Delete
        </.button>
      </div>

      <div :if={@categories == []} class="text-center py-16">
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
            d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
          />
        </svg>
        <p class="text-base-content/50 font-medium">No categories yet</p>
      </div>
    </div>
    """
  end

  attr(:storage_locations, :list, required: true)
  attr(:show_form, :atom, default: nil)
  attr(:form, :any, default: nil)

  defp locations_tab(assigns) do
    ~H"""
    <div class="flex justify-end mb-6">
      <.button
        phx-click="new_location"
        class="btn-accent"
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
      <div class="mb-6 bg-accent/5 border border-accent/20 rounded-xl p-6">
        <h3 class="text-lg font-semibold text-base-content mb-4">Add New Storage Location</h3>
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
                class="btn-ghost"
              >
                Cancel
              </.button>
              <.button
                type="submit"
                class="btn-accent"
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
        class="flex items-center justify-between p-5 bg-base-200/30 rounded-xl border border-base-200 hover:border-accent/30 hover:bg-accent/5 transition"
      >
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-accent/10 rounded-lg flex items-center justify-center flex-shrink-0">
            <svg
              class="w-6 h-6 text-accent"
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
            <div class="font-semibold text-base-content">{location.name}</div>
            <div
              :if={location.temperature_zone}
              class="text-sm text-accent mt-1 capitalize"
            >
              Temperature: {location.temperature_zone}
            </div>
          </div>
        </div>
        <.button
          phx-click="delete_location"
          phx-value-id={location.id}
          class="btn-error btn-outline btn-sm"
        >
          Delete
        </.button>
      </div>

      <div :if={@storage_locations == []} class="text-center py-16">
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
            d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
          />
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
          />
        </svg>
        <p class="text-base-content/50 font-medium">No storage locations yet</p>
      </div>
    </div>
    """
  end

  attr(:tags, :list, required: true)
  attr(:show_form, :atom, default: nil)
  attr(:form, :any, default: nil)
  attr(:editing_id, :any, default: nil)

  defp tags_tab(assigns) do
    ~H"""
    <div class="flex justify-end mb-6">
      <.button
        phx-click="new_tag"
        class="btn-secondary"
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
      <div class="mb-6 bg-secondary/5 border border-secondary/20 rounded-xl p-6">
        <h3 class="text-lg font-semibold text-base-content mb-4">
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
                class="btn-ghost"
              >
                Cancel
              </.button>
              <.button
                type="submit"
                class="btn-secondary"
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
        class="flex items-center justify-between p-5 bg-base-200/30 rounded-xl border border-base-200 hover:border-secondary/30 hover:bg-secondary/5 transition"
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
            <div class="font-semibold text-base-content">{tag.name}</div>
            <div :if={tag.description} class="text-sm text-base-content/60 mt-1">
              {tag.description}
            </div>
          </div>
        </div>
        <div class="flex gap-2">
          <.button
            phx-click="edit_tag"
            phx-value-id={tag.id}
            class="btn-ghost btn-sm"
          >
            Edit
          </.button>
          <.button
            phx-click="delete_tag"
            phx-value-id={tag.id}
            class="btn-error btn-outline btn-sm"
          >
            Delete
          </.button>
        </div>
      </div>

      <div :if={@tags == []} class="text-center py-16">
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
            d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
          />
        </svg>
        <p class="text-base-content/50 font-medium">No tags yet</p>
        <p class="text-base-content/30 text-sm mt-1">Create tags to organize your grocery items</p>
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
      |> assign(:form_params, %{})
      |> assign(:editing_id, nil)
      |> assign(:managing_tags_for, nil)
      |> assign(:show_tag_modal, false)
      |> assign(:filter_tag_ids, [])
      |> assign(:selected_tag_ids, [])
      |> assign(:expiring_filter, nil)
      |> assign(:inventory_page, 1)
      |> assign(:inventory_per_page, @inventory_per_page)
      |> assign(:inventory_total_count, 0)
      |> assign(:inventory_total_pages, 1)

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
      |> load_data()

    {:noreply, socket}
  end

  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("inventory_page", %{"page" => page}, socket) do
    page = String.to_integer(page)

    socket =
      socket
      |> assign(:inventory_page, page)
      |> load_data()

    {:noreply, socket}
  end

  def handle_event("new_item", _, socket) do
    {:noreply,
     assign(socket,
       show_form: :item,
       form: to_form(%{}, as: :item),
       form_params: %{},
       editing_id: nil,
       selected_tag_ids: []
     )}
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

  def handle_event("toggle_tag_filter", %{"tag-id" => tag_id}, socket) do
    current_filters = socket.assigns.filter_tag_ids

    new_filters =
      if tag_id in current_filters do
        List.delete(current_filters, tag_id)
      else
        [tag_id | current_filters]
      end

    socket =
      socket
      |> assign(:filter_tag_ids, new_filters)
      |> assign(:inventory_page, 1)
      |> load_data()

    {:noreply, socket}
  end

  def handle_event("clear_tag_filters", _, socket) do
    socket =
      socket
      |> assign(:filter_tag_ids, [])
      |> assign(:inventory_page, 1)
      |> load_data()

    {:noreply, socket}
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

  def handle_event("edit_item", %{"id" => id}, socket) do
    case GroceryPlanner.Inventory.get_grocery_item(id,
           actor: socket.assigns.current_user,
           tenant: socket.assigns.current_account.id,
           load: [:tags]
         ) do
      {:ok, item} ->
        form_params = %{
          "name" => item.name,
          "description" => item.description,
          "category_id" => item.category_id,
          "default_unit" => item.default_unit,
          "barcode" => item.barcode
        }

        form = to_form(form_params, as: :item)

        selected_tag_ids = Enum.map(item.tags || [], fn tag -> to_string(tag.id) end)

        {:noreply,
         assign(socket,
           show_form: :item,
           form: form,
           form_params: form_params,
           editing_id: id,
           selected_tag_ids: selected_tag_ids
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Item not found")}
    end
  end

  def handle_event("toggle_form_tag", %{"tag-id" => tag_id}, socket) do
    current = socket.assigns.selected_tag_ids

    new_selected =
      if tag_id in current do
        List.delete(current, tag_id)
      else
        [tag_id | current]
      end

    {:noreply, assign(socket, :selected_tag_ids, new_selected)}
  end

  def handle_event("validate_item", %{"item" => params}, socket) do
    new_params = Map.merge(socket.assigns.form_params || %{}, params)
    form = to_form(new_params, as: :item)
    {:noreply, assign(socket, form: form, form_params: new_params)}
  end

  def handle_event("suggest_category", _params, socket) do
    form_params = socket.assigns.form_params || %{}
    name = form_params["name"]

    if is_nil(name) || name == "" do
      {:noreply, put_flash(socket, :warning, "Please enter an item name first")}
    else
      categories = socket.assigns.categories
      labels = Enum.map(categories, & &1.name)

      context = %{
        tenant_id: socket.assigns.current_account.id,
        user_id: socket.assigns.current_user.id
      }

      case AiClient.categorize_item(name, labels, context) do
        {:ok, %{"payload" => %{"category" => predicted_category}}} ->
          case Enum.find(categories, fn c ->
                 String.downcase(c.name) == String.downcase(predicted_category)
               end) do
            nil ->
              {:noreply,
               put_flash(
                 socket,
                 :warning,
                 "Suggested category '#{predicted_category}' not found in list"
               )}

            category ->
              new_params = Map.put(form_params, "category_id", category.id)
              form = to_form(new_params, as: :item)

              socket =
                socket
                |> assign(form: form, form_params: new_params)
                |> put_flash(:info, "Suggested category: #{category.name}")

              {:noreply, socket}
          end

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not predict category")}
      end
    end
  end

  def handle_event("save_item", %{"item" => params}, socket) do
    account_id = socket.assigns.current_account.id
    # Filter out tag_ids from params - tags are synced separately via selected_tag_ids
    item_params = Map.drop(params, ["tag_ids"])

    result =
      if socket.assigns.editing_id do
        # Update existing item
        case GroceryPlanner.Inventory.get_grocery_item(
               socket.assigns.editing_id,
               actor: socket.assigns.current_user,
               tenant: account_id
             ) do
          {:ok, item} ->
            GroceryPlanner.Inventory.update_grocery_item(
              item,
              item_params,
              actor: socket.assigns.current_user,
              tenant: account_id
            )

          error ->
            error
        end
      else
        # Create new item
        case GroceryPlanner.Inventory.create_grocery_item!(
               account_id,
               item_params,
               authorize?: false,
               tenant: account_id
             ) do
          item when is_struct(item) -> {:ok, item}
          error -> error
        end
      end

    case result do
      {:ok, item} ->
        # Sync tag associations
        sync_item_tags(item.id, socket.assigns.selected_tag_ids, socket)

        action = if socket.assigns.editing_id, do: "updated", else: "created"

        socket =
          socket
          |> load_data()
          |> assign(show_form: nil, form: nil, editing_id: nil, selected_tag_ids: [])
          |> put_flash(:info, "Grocery item #{action} successfully")

        {:noreply, socket}

      {:error, _} ->
        action = if socket.assigns.editing_id, do: "update", else: "create"
        {:noreply, put_flash(socket, :error, "Failed to #{action} grocery item")}
    end
  end

  def handle_event("save_entry", %{"entry" => params}, socket) do
    account_id = socket.assigns.current_account.id
    grocery_item_id = params["grocery_item_id"]

    # Handle price with currency
    params =
      if params["purchase_price"] && params["purchase_price"] != "" do
        currency = socket.assigns.current_account.currency || "USD"

        Map.put(params, "purchase_price", %{
          "amount" => params["purchase_price"],
          "currency" => currency
        })
      else
        params
      end

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
        result =
          GroceryPlanner.Inventory.destroy_grocery_item(item,
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
        result =
          GroceryPlanner.Inventory.destroy_category(category,
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
        result =
          GroceryPlanner.Inventory.destroy_storage_location(location,
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

  def handle_event("manage_tags", %{"id" => id}, socket) do
    case GroceryPlanner.Inventory.get_grocery_item(id,
           actor: socket.assigns.current_user,
           tenant: socket.assigns.current_account.id,
           load: [:tags]
         ) do
      {:ok, item} ->
        {:noreply, assign(socket, managing_tags_for: item)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Item not found")}
    end
  end

  def handle_event("add_tag_to_item", %{"item-id" => item_id, "tag-id" => tag_id}, socket) do
    case GroceryPlanner.Inventory.create_grocery_item_tagging(
           %{grocery_item_id: item_id, tag_id: tag_id},
           authorize?: false
         ) do
      {:ok, _} ->
        # Reload the item with tags
        {:ok, updated_item} =
          GroceryPlanner.Inventory.get_grocery_item(item_id,
            actor: socket.assigns.current_user,
            tenant: socket.assigns.current_account.id,
            load: [:tags]
          )

        socket =
          socket
          |> assign(managing_tags_for: updated_item)
          |> load_data()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add tag")}
    end
  end

  def handle_event("remove_tag_from_item", %{"item-id" => item_id, "tag-id" => tag_id}, socket) do
    # Find the tagging and destroy it
    case GroceryPlanner.Inventory.list_grocery_item_taggings(
           actor: socket.assigns.current_user,
           query:
             GroceryPlanner.Inventory.GroceryItemTagging
             |> Ash.Query.filter(grocery_item_id == ^item_id and tag_id == ^tag_id)
         ) do
      {:ok, [tagging | _]} ->
        case GroceryPlanner.Inventory.destroy_grocery_item_tagging(tagging, authorize?: false) do
          :ok ->
            # Reload the item with tags
            {:ok, updated_item} =
              GroceryPlanner.Inventory.get_grocery_item(item_id,
                actor: socket.assigns.current_user,
                tenant: socket.assigns.current_account.id,
                load: [:tags]
              )

            socket =
              socket
              |> assign(managing_tags_for: updated_item)
              |> load_data()

            {:noreply, socket}

          {:ok, _} ->
            {:ok, updated_item} =
              GroceryPlanner.Inventory.get_grocery_item(item_id,
                actor: socket.assigns.current_user,
                tenant: socket.assigns.current_account.id,
                load: [:tags]
              )

            socket =
              socket
              |> assign(managing_tags_for: updated_item)
              |> load_data()

            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to remove tag")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Tag association not found")}
    end
  end

  def handle_event("cancel_tag_management", _, socket) do
    {:noreply, assign(socket, managing_tags_for: nil)}
  end

  def handle_event("delete_entry", %{"id" => id}, socket) do
    case GroceryPlanner.Inventory.get_inventory_entry(id,
           actor: socket.assigns.current_user,
           tenant: socket.assigns.current_account.id
         ) do
      {:ok, entry} ->
        result =
          GroceryPlanner.Inventory.destroy_inventory_entry(entry,
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

  def handle_event("consume_entry", %{"id" => id}, socket) do
    handle_usage_log(socket, id, :consumed)
  end

  def handle_event("expire_entry", %{"id" => id}, socket) do
    handle_usage_log(socket, id, :expired)
  end

  def handle_event("bulk_mark_expired", _params, socket) do
    # Find all entries that are past their use_by_date but still marked as available
    today = Date.utc_today()
    account_id = socket.assigns.current_account.id
    user = socket.assigns.current_user

    expired_entries =
      Enum.filter(socket.assigns.inventory_entries, fn entry ->
        entry.use_by_date && Date.compare(entry.use_by_date, today) == :lt &&
          entry.status == :available
      end)

    if Enum.empty?(expired_entries) do
      {:noreply, put_flash(socket, :info, "No expired items to update")}
    else
      results =
        Enum.map(expired_entries, fn entry ->
          # Create usage log
          GroceryPlanner.Analytics.UsageLog.create!(
            %{
              quantity: entry.quantity,
              unit: entry.unit,
              reason: :expired,
              occurred_at: DateTime.utc_now(),
              cost: entry.purchase_price,
              grocery_item_id: entry.grocery_item_id,
              account_id: account_id
            },
            authorize?: false,
            tenant: account_id
          )

          # Update entry status
          GroceryPlanner.Inventory.update_inventory_entry!(
            entry,
            %{status: :expired},
            actor: user,
            tenant: account_id
          )
        end)

      count = length(results)

      socket =
        socket
        |> load_data()
        |> put_flash(:info, "#{count} item#{if count != 1, do: "s", else: ""} marked as expired")

      {:noreply, socket}
    end
  end

  def handle_event("bulk_consume_available", _params, socket) do
    account_id = socket.assigns.current_account.id
    user = socket.assigns.current_user

    available_entries =
      Enum.filter(socket.assigns.inventory_entries, fn entry ->
        entry.status == :available
      end)

    if Enum.empty?(available_entries) do
      {:noreply, put_flash(socket, :info, "No available items to consume")}
    else
      results =
        Enum.map(available_entries, fn entry ->
          # Create usage log
          GroceryPlanner.Analytics.UsageLog.create!(
            %{
              quantity: entry.quantity,
              unit: entry.unit,
              reason: :consumed,
              occurred_at: DateTime.utc_now(),
              cost: entry.purchase_price,
              grocery_item_id: entry.grocery_item_id,
              account_id: account_id
            },
            authorize?: false,
            tenant: account_id
          )

          # Update entry status
          GroceryPlanner.Inventory.update_inventory_entry!(
            entry,
            %{status: :consumed},
            actor: user,
            tenant: account_id
          )
        end)

      count = length(results)

      socket =
        socket
        |> load_data()
        |> put_flash(:info, "#{count} item#{if count != 1, do: "s", else: ""} marked as consumed")

      {:noreply, socket}
    end
  end

  defp handle_usage_log(socket, entry_id, reason) do
    account_id = socket.assigns.current_account.id
    user = socket.assigns.current_user

    case GroceryPlanner.Inventory.get_inventory_entry(entry_id,
           actor: user,
           tenant: account_id
         ) do
      {:ok, entry} ->
        # Create usage log
        GroceryPlanner.Analytics.UsageLog.create!(
          %{
            quantity: entry.quantity,
            unit: entry.unit,
            reason: reason,
            occurred_at: DateTime.utc_now(),
            cost: entry.purchase_price,
            grocery_item_id: entry.grocery_item_id,
            account_id: account_id
          },
          authorize?: false,
          tenant: account_id
        )

        # Update entry status
        GroceryPlanner.Inventory.update_inventory_entry!(
          entry,
          %{status: reason},
          actor: user,
          tenant: account_id
        )

        socket =
          socket
          |> load_data()
          |> put_flash(:info, "Item marked as #{reason}")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Entry not found")}
    end
  end

  defp sync_item_tags(item_id, selected_tag_ids, socket) do
    # Get current tags for this item
    {:ok, current_taggings} =
      GroceryPlanner.Inventory.list_grocery_item_taggings(
        actor: socket.assigns.current_user,
        query:
          GroceryPlanner.Inventory.GroceryItemTagging
          |> Ash.Query.filter(grocery_item_id == ^item_id)
      )

    current_tag_ids = Enum.map(current_taggings, fn t -> to_string(t.tag_id) end)

    # Tags to add
    tags_to_add = selected_tag_ids -- current_tag_ids

    # Tags to remove
    tags_to_remove = current_tag_ids -- selected_tag_ids

    # Add new tags
    for tag_id <- tags_to_add do
      GroceryPlanner.Inventory.create_grocery_item_tagging(
        %{grocery_item_id: item_id, tag_id: tag_id},
        authorize?: false
      )
    end

    # Remove old tags
    for tag_id <- tags_to_remove do
      tagging = Enum.find(current_taggings, &(&1.tag_id == tag_id))

      if tagging do
        GroceryPlanner.Inventory.destroy_grocery_item_tagging(tagging, authorize?: false)
      end
    end
  end

  def format_expiring_filter("expired"), do: "Expired Items"
  def format_expiring_filter("today"), do: "Expires Today"
  def format_expiring_filter("tomorrow"), do: "Expires Tomorrow"
  def format_expiring_filter("this_week"), do: "Expires This Week (2-3 days)"
  def format_expiring_filter(_), do: "All Items"

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

    {:ok, items} =
      GroceryPlanner.Inventory.list_grocery_items(
        actor: user,
        tenant: account_id,
        query: items_query
      )

    {:ok, categories} = GroceryPlanner.Inventory.list_categories(actor: user, tenant: account_id)

    {:ok, locations} =
      GroceryPlanner.Inventory.list_storage_locations(actor: user, tenant: account_id)

    {:ok, tags} =
      GroceryPlanner.Inventory.list_grocery_item_tags(authorize?: false, tenant: account_id)

    # Build inventory entries query with expiration filter
    entries_query =
      InventoryEntry
      |> Ash.Query.load([:grocery_item, :storage_location, :days_until_expiry, :is_expired])
      |> filter(status == :available)

    entries_query =
      case socket.assigns[:expiring_filter] do
        "expired" ->
          entries_query
          |> filter(is_expired == true)

        "today" ->
          entries_query
          |> filter(not is_nil(use_by_date))
          |> filter(fragment("DATE(?) = CURRENT_DATE", use_by_date))

        "tomorrow" ->
          entries_query
          |> filter(not is_nil(use_by_date))
          |> filter(fragment("DATE(?) = CURRENT_DATE + INTERVAL '1 day'", use_by_date))

        "this_week" ->
          entries_query
          |> filter(not is_nil(use_by_date))
          |> filter(
            fragment(
              "DATE(?) BETWEEN CURRENT_DATE + INTERVAL '2 days' AND CURRENT_DATE + INTERVAL '3 days'",
              use_by_date
            )
          )

        _ ->
          entries_query
      end

    {:ok, all_entries} =
      GroceryPlanner.Inventory.list_inventory_entries(
        actor: user,
        tenant: account_id,
        query: entries_query
      )

    # Paginate inventory entries
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
end
