defmodule GroceryPlanner.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      GroceryPlannerWeb.Telemetry,
      GroceryPlanner.Repo,
      {Oban,
       AshOban.config([GroceryPlanner.Inventory], Application.fetch_env!(:grocery_planner, Oban))},
      {DNSCluster, query: Application.get_env(:grocery_planner, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: GroceryPlanner.PubSub},
      # Start a worker by calling: GroceryPlanner.Worker.start_link(arg)
      # {GroceryPlanner.Worker, arg},
      # Start to serve requests, typically the last entry
      GroceryPlannerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GroceryPlanner.Supervisor]
    result = Supervisor.start_link(children, opts)

    # Validate AI service connectivity after supervision tree starts (non-blocking)
    if Application.get_env(:grocery_planner, :validate_ai_service, false) do
      Task.start(fn ->
        Process.sleep(2_000)
        validate_ai_service()
      end)
    end

    result
  end

  defp validate_ai_service do
    require_ai_service? = Application.get_env(:grocery_planner, :require_ai_service, false)

    case GroceryPlanner.AiClient.health_check() do
      {:ok, %{"status" => "ok"} = body} ->
        Logger.info("AI service connected: #{inspect(body)}")

      {:ok, %{"status" => "degraded"} = body} ->
        Logger.warning("AI service degraded: #{inspect(body)}")

      {:error, reason} ->
        if require_ai_service? do
          Logger.error("AI service unavailable (required): #{inspect(reason)}")
          System.stop(1)
        else
          Logger.warning("AI service unavailable: #{inspect(reason)}. AI features disabled.")
        end
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GroceryPlannerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
