defmodule GroceryPlannerWeb.DashboardLive do
  use GroceryPlannerWeb, :live_view

  on_mount {GroceryPlannerWeb.Auth, :require_authenticated_user}

  def mount(_params, _session, socket) do
    socket = assign(socket, :current_scope, socket.assigns.current_account)
    {:ok, socket}
  end
end
