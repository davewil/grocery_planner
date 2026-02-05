defmodule GroceryPlannerWeb.HealthController do
  use GroceryPlannerWeb, :controller

  def check(conn, _params) do
    checks = %{
      database: check_database(),
      ai_service: check_ai_service(),
      oban: check_oban()
    }

    status = determine_status(checks)

    conn
    |> put_status(if status == "ok", do: 200, else: 503)
    |> json(%{
      status: status,
      checks: checks,
      version: to_string(Application.spec(:grocery_planner, :vsn))
    })
  end

  defp check_database do
    case Ecto.Adapters.SQL.query(GroceryPlanner.Repo, "SELECT 1", []) do
      {:ok, _} -> %{status: "ok"}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end

  defp check_ai_service do
    case GroceryPlanner.AiClient.health_check() do
      {:ok, body} -> %{status: body["status"], details: body["checks"]}
      {:error, _reason} -> %{status: "unavailable"}
    end
  end

  defp check_oban do
    case Oban.check_queue(conf: Oban, queue: :default) do
      %{paused: paused} ->
        %{status: if(paused, do: "paused", else: "ok")}

      _ ->
        %{status: "ok"}
    end
  rescue
    _ -> %{status: "unknown"}
  end

  defp determine_status(checks) do
    cond do
      checks.database.status != "ok" -> "error"
      checks.ai_service.status in ["error", "unavailable"] -> "degraded"
      true -> "ok"
    end
  end
end
