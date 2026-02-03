defmodule GroceryPlannerWeb.InventoryLive.TabNavigation do
  use GroceryPlannerWeb, :html

  attr(:active_tab, :string, required: true)

  def tab_navigation(assigns) do
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
end
