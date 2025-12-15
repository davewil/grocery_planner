defmodule GroceryPlannerWeb.AnalyticsLive do
  use GroceryPlannerWeb, :live_view
  alias GroceryPlanner.Analytics

  on_mount({GroceryPlannerWeb.Auth, :require_authenticated_user})

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:current_scope, socket.assigns.current_account)
      |> assign(:page_title, "Analytics")
      |> load_data()

    {:ok, socket}
  end

  defp load_data(socket) do
    account_id = socket.assigns.current_account.id
    user = socket.assigns.current_user

    currency = String.to_atom(socket.assigns.current_account.currency || "USD")
    inventory_summary = Analytics.get_inventory_summary(account_id, currency, user)
    expiration_summary = Analytics.get_expiration_summary(account_id, user)
    category_breakdown = Analytics.get_category_breakdown(account_id, user)
    waste_stats = Analytics.get_waste_stats(account_id, currency, user)

    socket
    |> assign(:inventory_summary, inventory_summary)
    |> assign(:expiration_summary, expiration_summary)
    |> assign(:category_breakdown, category_breakdown)
    |> assign(:waste_stats, waste_stats)
  end

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
          <h1 class="text-4xl font-bold text-gray-900">Analytics Dashboard</h1>
          <p class="mt-2 text-lg text-gray-600">
            Insights into your inventory, spending, and waste
          </p>
        </div>

    <!-- KPI Cards -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
            <div class="flex items-center gap-4">
              <div class="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center text-blue-600">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"
                  />
                </svg>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-500">Total Inventory</p>
                <div class="flex items-baseline gap-2">
                  <h3 class="text-2xl font-bold text-gray-900">{@inventory_summary.total_items}</h3>
                  <span class="text-sm text-gray-500">items</span>
                </div>
                <p class="text-xs text-gray-400 mt-1">
                  {@inventory_summary.total_entries} individual units
                </p>
              </div>
            </div>
          </div>

          <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
            <div class="flex items-center gap-4">
              <div class="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center text-green-600">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-500">Total Value</p>
                <h3 class="text-2xl font-bold text-gray-900">
                  {Money.to_string!(@inventory_summary.total_value)}
                </h3>
                <p class="text-xs text-gray-400 mt-1">Estimated based on purchase price</p>
              </div>
            </div>
          </div>

          <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
            <div class="flex items-center gap-4">
              <div class="w-12 h-12 bg-red-100 rounded-xl flex items-center justify-center text-red-600">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                  />
                </svg>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-500">Expiring Soon</p>
                <div class="flex items-baseline gap-2">
                  <h3 class="text-2xl font-bold text-gray-900">
                    {@expiration_summary.expiring_7_days}
                  </h3>
                  <span class="text-sm text-gray-500">items</span>
                </div>
                <p class="text-xs text-red-500 mt-1">
                  {@expiration_summary.expired_count} already expired
                </p>
              </div>
            </div>
          </div>

          <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
            <div class="flex items-center gap-4">
              <div class="w-12 h-12 bg-gray-100 rounded-xl flex items-center justify-center text-gray-600">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                  />
                </svg>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-500">Total Waste</p>
                <div class="flex items-baseline gap-2">
                  <h3 class="text-2xl font-bold text-gray-900">{@waste_stats.wasted_count}</h3>
                  <span class="text-sm text-gray-500">items</span>
                </div>
                <p class="text-xs text-red-500 mt-1">
                  {Money.to_string!(@waste_stats.total_wasted_cost)} lost
                  ({Float.round(@waste_stats.waste_percentage, 1)}%)
                </p>
              </div>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Category Breakdown -->
          <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
            <h3 class="text-lg font-semibold text-gray-900 mb-6">Inventory by Category</h3>
            <div class="space-y-4">
              <%= for category <- @category_breakdown do %>
                <div class="flex items-center gap-4">
                  <div class="w-32 text-sm font-medium text-gray-600 truncate" title={category.name}>
                    {category.name}
                  </div>
                  <div class="flex-1 h-4 bg-gray-100 rounded-full overflow-hidden">
                    <div
                      class="h-full bg-blue-500 rounded-full"
                      style={"width: #{if @inventory_summary.total_items > 0, do: (category.count / @inventory_summary.total_items) * 100, else: 0}%"}
                    >
                    </div>
                  </div>
                  <div class="w-12 text-right text-sm font-bold text-gray-900">
                    {category.count}
                  </div>
                </div>
              <% end %>
              <%= if Enum.empty?(@category_breakdown) do %>
                <p class="text-center text-gray-500 py-8">No inventory data available</p>
              <% end %>
            </div>
          </div>

    <!-- Expiration Timeline (Simple Visual) -->
          <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
            <h3 class="text-lg font-semibold text-gray-900 mb-6">Expiration Timeline</h3>
            <div class="space-y-6">
              <div class="flex items-center justify-between p-4 bg-red-50 rounded-xl border border-red-100">
                <div class="flex items-center gap-3">
                  <div class="w-2 h-2 rounded-full bg-red-500"></div>
                  <span class="font-medium text-red-900">Already Expired</span>
                </div>
                <span class="text-xl font-bold text-red-700">
                  {@expiration_summary.expired_count}
                </span>
              </div>

              <div class="flex items-center justify-between p-4 bg-orange-50 rounded-xl border border-orange-100">
                <div class="flex items-center gap-3">
                  <div class="w-2 h-2 rounded-full bg-orange-500"></div>
                  <span class="font-medium text-orange-900">Next 7 Days</span>
                </div>
                <span class="text-xl font-bold text-orange-700">
                  {@expiration_summary.expiring_7_days}
                </span>
              </div>

              <div class="flex items-center justify-between p-4 bg-yellow-50 rounded-xl border border-yellow-100">
                <div class="flex items-center gap-3">
                  <div class="w-2 h-2 rounded-full bg-yellow-500"></div>
                  <span class="font-medium text-yellow-900">Next 30 Days</span>
                </div>
                <span class="text-xl font-bold text-yellow-700">
                  {@expiration_summary.expiring_30_days}
                </span>
              </div>
            </div>

            <div class="mt-8 pt-6 border-t border-gray-100">
              <h4 class="text-sm font-medium text-gray-900 mb-3">Quick Actions</h4>
              <div class="grid grid-cols-2 gap-3">
                <.link
                  navigate={~p"/inventory?expiring=expired"}
                  class="flex items-center justify-center px-4 py-2 border border-gray-200 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50 transition"
                >
                  Remove Expired
                </.link>
                <.link
                  navigate={~p"/inventory?expiring=this_week"}
                  class="flex items-center justify-center px-4 py-2 border border-gray-200 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50 transition"
                >
                  View Expiring
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
