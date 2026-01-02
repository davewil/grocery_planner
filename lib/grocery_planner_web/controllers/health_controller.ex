defmodule GroceryPlannerWeb.HealthController do
  use GroceryPlannerWeb, :controller

  def check(conn, _params) do
    # In a real app, you might check DB connectivity here:
    # case Ecto.Adapters.SQL.query(GroceryPlanner.Repo, "SELECT 1") do
    #   {:ok, _} -> text(conn, "OK")
    #   _ -> send_resp(conn, 503, "Service Unavailable")
    # end
    text(conn, "OK")
  end
end
