defmodule GroceryPlannerWeb.InventoryLive.ItemsTab do
  use GroceryPlannerWeb, :html

  attr(:items, :list, required: true)
  attr(:tags, :list, required: true)
  attr(:filter_tag_ids, :list, required: true)
  attr(:show_form, :atom, default: nil)
  attr(:form, :any, default: nil)
  attr(:editing_id, :any, default: nil)
  attr(:managing_tags_for, :any, default: nil)
  attr(:categories, :list, required: true)
  attr(:selected_tag_ids, :list, default: [])
  attr(:category_suggestion, :map, default: nil)
  attr(:category_suggestion_loading, :boolean, default: false)

  def items_tab(assigns) do
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
          <.input
            field={@form[:name]}
            type="text"
            label="Name"
            required
            phx-debounce="500"
          />
          <.input field={@form[:description]} type="text" label="Description" />
          <.input
            field={@form[:default_unit]}
            type="text"
            label="Default Unit"
            placeholder="e.g., lbs, oz, liters"
          />
          <.input field={@form[:barcode]} type="text" label="Barcode (optional)" />

          <div>
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

            <%!-- AI Category Suggestion Chip --%>
            <%= if @category_suggestion_loading do %>
              <div class="mt-2 flex items-center gap-2 text-sm text-base-content/60">
                <span class="loading loading-spinner loading-xs"></span>
                <span>Analyzing item...</span>
              </div>
            <% end %>

            <%= if @category_suggestion do %>
              <div class="mt-2 flex items-center gap-2 flex-wrap">
                <span class="text-sm text-base-content/70">Suggested:</span>
                <button
                  type="button"
                  class="badge badge-primary cursor-pointer hover:badge-primary/80 transition gap-1"
                  phx-click="accept_suggestion"
                >
                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"
                    />
                  </svg>
                  {@category_suggestion.category.name}
                </button>
                <span class={[
                  "badge badge-sm gap-1",
                  case @category_suggestion.confidence_level do
                    "high" -> "badge-success"
                    "medium" -> "badge-warning"
                    _ -> "badge-ghost"
                  end
                ]}>
                  <%= case @category_suggestion.confidence_level do %>
                    <% "high" -> %>
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M5 13l4 4L19 7"
                        />
                      </svg>
                    <% "medium" -> %>
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01"
                        />
                      </svg>
                    <% _ -> %>
                  <% end %>
                  {round(@category_suggestion.confidence * 100)}%
                </span>
              </div>
            <% end %>
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
end
