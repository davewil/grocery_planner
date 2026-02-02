Postgrex.Types.define(
  GroceryPlanner.PostgrexTypes,
  [AshPostgres.Extensions.Vector] ++ Ecto.Adapters.Postgres.extensions(),
  []
)
