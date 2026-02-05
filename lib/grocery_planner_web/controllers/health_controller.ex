defmodule GroceryPlannerWeb.HealthController do
  use GroceryPlannerWeb, :controller

  @doc """
  Basic liveness check for load balancers.
  Returns 200 OK if the Elixir application is running.
  """
  def check(conn, _params) do
    json(conn, %{status: "ok"})
  end

  @doc """
  Full readiness check with dependency validation.
  Checks database, AI service, and Oban job queue health.
  Returns 200 if all critical services are healthy, 503 otherwise.
  """
  def ready(conn, _params) do
    checks = %{
      database: check_database(),
      ai_service: check_ai_service(),
      oban: check_oban()
    }

    status = determine_status(checks)

    conn
    |> put_status(if(status == "ok" or status == "degraded", do: 200, else: 503))
    |> json(%{
      status: status,
      checks: checks,
      version: Application.spec(:grocery_planner, :vsn) |> to_string()
    })
  end

  defp check_database do
    case Ecto.Adapters.SQL.query(GroceryPlanner.Repo, "SELECT 1", []) do
      {:ok, _} -> %{status: "ok"}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end

  defp check_ai_service do
    case GroceryPlanner.AiClient.health_check(receive_timeout: 3_000) do
      {:ok, body} -> %{status: body["status"] || "ok", details: body["checks"]}
      {:error, {:unhealthy, _status, body}} -> %{status: "error", error: inspect(body)}
      {:error, {:connection_failed, reason}} -> %{status: "unavailable", error: inspect(reason)}
    end
  end

  defp check_oban do
    if Process.whereis(Oban) do
      %{status: "ok"}
    else
      %{status: "error", error: "Oban process not running"}
    end
  rescue
    _ -> %{status: "error", error: "Failed to check Oban status"}
  end

  defp determine_status(checks) do
    cond do
      checks.database.status != "ok" -> "error"
      checks.ai_service.status in ["error", "unavailable"] -> "degraded"
      true -> "ok"
    end
  end
end
