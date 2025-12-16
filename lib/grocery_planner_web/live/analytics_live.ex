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
    spending_trends = Analytics.get_spending_trends(account_id, currency, user)
    usage_trends = Analytics.get_usage_trends(account_id, user)
    most_wasted_items = Analytics.get_most_wasted_items(account_id, currency, user)

    max_spending =
      if Enum.empty?(spending_trends),
        do: 1,
        else:
          Enum.max_by(spending_trends, fn %{amount: amount} -> Money.to_decimal(amount) end).amount
          |> Money.to_decimal()
          |> Decimal.to_float()

    max_usage =
      if Enum.empty?(usage_trends),
        do: 1,
        else:
          Enum.max_by(usage_trends, fn %{consumed: c, wasted: w} -> c + w end)
          |> then(fn %{consumed: c, wasted: w} -> c + w end)

    socket
    |> assign(:inventory_summary, inventory_summary)
    |> assign(:expiration_summary, expiration_summary)
    |> assign(:category_breakdown, category_breakdown)
    |> assign(:waste_stats, waste_stats)
    |> assign(:spending_trends, spending_trends)
    |> assign(:usage_trends, usage_trends)
    |> assign(:most_wasted_items, most_wasted_items)
    |> assign(:max_spending, max_spending)
    |> assign(:max_usage, max_usage)
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

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          <!-- Spending Trends -->
          <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
            <h3 class="text-lg font-semibold text-gray-900 mb-6">Spending Trends (Last 30 Days)</h3>
            <div class="h-64 flex items-end gap-2">
              <%= if Enum.empty?(@spending_trends) do %>
                <div class="w-full h-full flex items-center justify-center text-gray-500">
                  No spending data available
                </div>
              <% else %>
                <%= for point <- @spending_trends do %>
                  <div class="flex-1 flex flex-col items-center group relative">
                    <div
                      class="w-full bg-blue-500 rounded-t-sm hover:bg-blue-600 transition-all"
                      style={"height: #{max((Money.to_decimal(point.amount) |> Decimal.to_float()) / @max_spending * 100, 1)}%"}
                    >
                    </div>
                    <!-- Tooltip -->
                    <div class="absolute bottom-full mb-2 hidden group-hover:block z-10 bg-gray-900 text-white text-xs rounded py-1 px-2 whitespace-nowrap">
                      {Calendar.strftime(point.date, "%b %d")}: {Money.to_string!(point.amount)}
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
            <div class="flex justify-between mt-2 text-xs text-gray-500">
              <span>30 days ago</span>
              <span>Today</span>
            </div>
          </div>
          
    <!-- Usage Trends -->
          <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
            <h3 class="text-lg font-semibold text-gray-900 mb-6">Usage Trends (Last 30 Days)</h3>
            <div class="h-64 flex items-end gap-2">
              <%= if Enum.empty?(@usage_trends) do %>
                <div class="w-full h-full flex items-center justify-center text-gray-500">
                  No usage data available
                </div>
              <% else %>
                <%= for point <- @usage_trends do %>
                  <div class="flex-1 flex flex-col justify-end group relative gap-px">
                    <!-- Wasted Bar -->
                    <div
                      class="w-full bg-red-400 hover:bg-red-500 transition-all"
                      style={"height: #{if @max_usage > 0, do: (point.wasted / @max_usage) * 100, else: 0}%"}
                    >
                    </div>
                    <!-- Consumed Bar -->
                    <div
                      class="w-full bg-green-500 hover:bg-green-600 transition-all"
                      style={"height: #{if @max_usage > 0, do: (point.consumed / @max_usage) * 100, else: 0}%"}
                    >
                    </div>
                    
    <!-- Tooltip -->
                    <div class="absolute bottom-full mb-2 hidden group-hover:block z-10 bg-gray-900 text-white text-xs rounded py-1 px-2 whitespace-nowrap">
                      <div class="font-bold">{point.date}</div>
                      <div class="text-green-300">Consumed: {point.consumed}</div>
                      <div class="text-red-300">Wasted: {point.wasted}</div>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
            <div class="flex items-center justify-center gap-4 mt-4 text-sm">
              <div class="flex items-center gap-2">
                <div class="w-3 h-3 bg-green-500 rounded-sm"></div>
                <span class="text-gray-600">Consumed</span>
              </div>
              <div class="flex items-center gap-2">
                <div class="w-3 h-3 bg-red-400 rounded-sm"></div>
                <span class="text-gray-600">Wasted</span>
              </div>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Most Wasted Items -->
          <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
            <h3 class="text-lg font-semibold text-gray-900 mb-6">Most Wasted Items</h3>
            <div class="overflow-hidden">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th
                      scope="col"
                      class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                    >
                      Item
                    </th>
                    <th
                      scope="col"
                      class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                    >
                      Times Wasted
                    </th>
                    <th
                      scope="col"
                      class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                    >
                      Total Cost
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for item <- @most_wasted_items do %>
                    <tr>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                        {item.name}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {item.count}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-red-600 font-medium">
                        {Money.to_string!(item.total_cost)}
                      </td>
                    </tr>
                  <% end %>
                  <%= if Enum.empty?(@most_wasted_items) do %>
                    <tr>
                      <td colspan="3" class="px-6 py-8 text-center text-gray-500">
                        No waste recorded yet. Good job!
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
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
