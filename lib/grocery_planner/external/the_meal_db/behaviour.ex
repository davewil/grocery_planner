defmodule GroceryPlanner.External.TheMealDB.Behaviour do
  @moduledoc false
  @callback search(String.t()) :: {:ok, map()} | {:error, any()}
  @callback get(String.t()) :: {:ok, map()} | {:error, any()}
  @callback random() :: {:ok, map()} | {:error, any()}
  @callback categories() :: {:ok, map()} | {:error, any()}
  @callback filter(keyword()) :: {:ok, map()} | {:error, any()}
end
