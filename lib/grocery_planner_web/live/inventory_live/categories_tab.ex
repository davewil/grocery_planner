defmodule GroceryPlannerWeb.InventoryLive.CategoriesTab do
  use GroceryPlannerWeb, :html

  attr(:categories, :list, required: true)
  attr(:show_form, :atom, default: nil)
  attr(:form, :any, default: nil)

  def categories_tab(assigns) do
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
            <.icon
              :if={category.icon && String.starts_with?(category.icon, "hero-")}
              name={category.icon}
              class="w-6 h-6 text-secondary"
            />
            <svg
              :if={!category.icon || !String.starts_with?(category.icon, "hero-")}
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
end
