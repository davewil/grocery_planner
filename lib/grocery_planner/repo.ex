defmodule GroceryPlanner.Repo do
  use AshPostgres.Repo,
    otp_app: :grocery_planner

  @impl true
  def installed_extensions do
    ["ash-functions", "citext", "vector", AshMoney.AshPostgresExtension]
  end

  @impl true
  def init(_type, config) do
    {:ok, Keyword.put(config, :types, GroceryPlanner.PostgrexTypes)}
  end

  # Don't open unnecessary transactions
  # will default to `false` in 4.0
  @impl true
  def prefer_transaction? do
    false
  end

  @impl true
  def min_pg_version do
    %Version{major: 18, minor: 0, patch: 0}
  end
end
