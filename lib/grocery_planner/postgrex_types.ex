Postgrex.Types.define(
  GroceryPlanner.PostgrexTypes,
  [Pgvector.Extensions.Vector] ++ Ecto.Adapters.Postgres.extensions(),
  []
)
