defmodule GroceryPlannerWeb.PageController do
  use GroceryPlannerWeb, :controller

  def home(conn, _params) do
    if conn.assigns.current_user do
      redirect(conn, to: "/dashboard")
    else
      render(conn, :home, layout: false)
    end
  end
end
