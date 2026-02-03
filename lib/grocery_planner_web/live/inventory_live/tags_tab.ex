defmodule GroceryPlannerWeb.InventoryLive.TagsTab do
  use GroceryPlannerWeb, :html

  attr(:tags, :list, required: true)
  attr(:show_form, :atom, default: nil)
  attr(:form, :any, default: nil)
  attr(:editing_id, :any, default: nil)

  def tags_tab(assigns) do
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
end
