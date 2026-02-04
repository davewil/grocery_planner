defmodule GroceryPlanner.IntegrationCase do
  @moduledoc """
  ExUnit CaseTemplate for integration tests that exercise the real
  Elixir → Python AI service HTTP path.

  Sets up Ecto sandbox and overrides ai_client_opts to remove
  the Req.Test plug, enabling real HTTP calls to the Python service.

  ## Usage

      use GroceryPlanner.IntegrationCase, async: false

  ## Environment

  Set `AI_SERVICE_URL` to point at the Python service.
  Defaults to `http://localhost:8099`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias GroceryPlanner.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import GroceryPlanner.IntegrationCase
      import GroceryPlanner.InventoryTestHelpers
    end
  end

  setup tags do
    # Set up Ecto sandbox (same as DataCase)
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(GroceryPlanner.Repo, shared: not tags[:async])

    # Save original config and override to remove Req.Test plug (enable real HTTP)
    original_opts = Application.get_env(:grocery_planner, :ai_client_opts)
    Application.put_env(:grocery_planner, :ai_client_opts, [])

    on_exit(fn ->
      # Restore original config
      if original_opts do
        Application.put_env(:grocery_planner, :ai_client_opts, original_opts)
      else
        Application.delete_env(:grocery_planner, :ai_client_opts)
      end

      Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
    end)

    :ok
  end

  @doc """
  Returns the AI service URL from environment or default.
  """
  def ai_service_url do
    System.get_env("AI_SERVICE_URL") || "http://localhost:8099"
  end

  @doc """
  Checks if the Python AI service is reachable.
  """
  def service_healthy? do
    case Req.get(Req.new(base_url: ai_service_url()), url: "/health") do
      {:ok, %Req.Response{status: 200}} -> true
      _ -> false
    end
  end
end
