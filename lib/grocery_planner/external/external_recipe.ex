defmodule GroceryPlanner.External.ExternalRecipe do
  @moduledoc """
  Ash resource wrapping external recipe data from TheMealDB API.

  Uses Simple data layer (no database persistence) with manual actions
  that fetch data from the external API.
  """

  use Ash.Resource,
    domain: GroceryPlanner.External,
    data_layer: Ash.DataLayer.Simple

  alias GroceryPlanner.External.TheMealDB

  actions do
    defaults []

    read :search do
      description "Search for recipes by name from TheMealDB"
      argument :query, :string, allow_nil?: false

      manual fn query, _ecto_query, _opts ->
        search_term = query.arguments.query

        case TheMealDB.search_by_name(search_term) do
          {:ok, meals} ->
            {:ok, Enum.map(meals, &struct(__MODULE__, &1))}

          {:error, reason} ->
            {:error, Ash.Error.Invalid.InvalidQuery.exception(message: inspect(reason))}
        end
      end
    end

    read :by_id do
      description "Get a specific recipe by TheMealDB ID"
      argument :id, :string, allow_nil?: false

      get? true

      manual fn query, _ecto_query, _opts ->
        meal_id = query.arguments.id

        case TheMealDB.get_by_id(meal_id) do
          {:ok, meal} ->
            {:ok, [struct(__MODULE__, meal)]}

          {:error, :not_found} ->
            {:ok, []}

          {:error, reason} ->
            {:error, Ash.Error.Invalid.InvalidQuery.exception(message: inspect(reason))}
        end
      end
    end

    read :random do
      description "Get a random recipe from TheMealDB"

      manual fn _query, _ecto_query, _opts ->
        case TheMealDB.random_meal() do
          {:ok, meal} ->
            {:ok, [struct(__MODULE__, meal)]}

          {:error, reason} ->
            {:error, Ash.Error.Invalid.InvalidQuery.exception(message: inspect(reason))}
        end
      end
    end

    read :by_category do
      description "Filter recipes by category from TheMealDB"
      argument :category, :string, allow_nil?: false

      manual fn query, _ecto_query, _opts ->
        category = query.arguments.category

        case TheMealDB.filter_by_category(category) do
          {:ok, meals} ->
            {:ok, Enum.map(meals, &struct(__MODULE__, &1))}

          {:error, reason} ->
            {:error, Ash.Error.Invalid.InvalidQuery.exception(message: inspect(reason))}
        end
      end
    end
  end

  attributes do
    # Using string for ID since TheMealDB uses numeric string IDs
    attribute :external_id, :string do
      allow_nil? false
      public? true
      primary_key? true
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :category, :string do
      public? true
    end

    attribute :area, :string do
      public? true
    end

    attribute :instructions, :string do
      public? true
    end

    attribute :image_url, :string do
      public? true
    end

    attribute :youtube_url, :string do
      public? true
    end

    attribute :source_url, :string do
      public? true
    end

    # Embedded list of ingredient maps
    attribute :ingredients, {:array, :map} do
      default []
      public? true
    end

    # List of tag strings
    attribute :tags, {:array, :string} do
      default []
      public? true
    end
  end

  calculations do
    calculate :recipe_attrs, :map do
      description "Convert to Recipe resource attributes format"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          {record, TheMealDB.to_recipe_attrs(Map.from_struct(record))}
        end)
        |> Map.new()
      end
    end
  end
end
