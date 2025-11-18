defmodule GroceryPlanner.External.TheMealDB do
  @moduledoc """
  Client for TheMealDB API (https://www.themealdb.com)
  Provides access to free recipe data.

  Supports dependency injection via `opts` parameter for testing.
  Pass `plug: {Req.Test, name}` to use test stubs.
  """

  @base_url "https://www.themealdb.com/api/json/v1/1"

  @doc """
  Search for meals by name.

  Returns a list of meals matching the search term.

  ## Examples

      iex> TheMealDB.search_by_name("chicken")
      {:ok, [%{id: "52940", name: "Chicken Teriyaki", ...}, ...]}

      iex> TheMealDB.search_by_name("chicken", plug: {Req.Test, TheMealDB})
      {:ok, [%{id: "52940", name: "Chicken Teriyaki", ...}, ...]}
  """
  def search_by_name(query, opts \\ []) when is_binary(query) do
    case req(opts) |> Req.get(url: "/search.php", params: [s: query]) do
      {:ok, %{status: 200, body: %{"meals" => meals}}} when is_list(meals) ->
        {:ok, Enum.map(meals, &parse_meal/1)}

      {:ok, %{status: 200, body: %{"meals" => nil}}} ->
        {:ok, []}

      {:ok, %{status: status}} ->
        {:error, "API returned status #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get a random meal from the API.
  """
  def random_meal(opts \\ []) do
    case req(opts) |> Req.get(url: "/random.php") do
      {:ok, %{status: 200, body: %{"meals" => [meal]}}} ->
        {:ok, parse_meal(meal)}

      {:ok, %{status: status}} ->
        {:error, "API returned status #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get full meal details by ID.
  """
  def get_by_id(id, opts \\ []) when is_binary(id) do
    case req(opts) |> Req.get(url: "/lookup.php", params: [i: id]) do
      {:ok, %{status: 200, body: %{"meals" => [meal]}}} ->
        {:ok, parse_meal(meal)}

      {:ok, %{status: 200, body: %{"meals" => nil}}} ->
        {:error, :not_found}

      {:ok, %{status: status}} ->
        {:error, "API returned status #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  List all meal categories.
  """
  def list_categories(opts \\ []) do
    case req(opts) |> Req.get(url: "/categories.php") do
      {:ok, %{status: 200, body: %{"categories" => categories}}} when is_list(categories) ->
        {:ok, categories}

      {:ok, %{status: status}} ->
        {:error, "API returned status #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Filter meals by category.
  """
  def filter_by_category(category, opts \\ []) when is_binary(category) do
    case req(opts) |> Req.get(url: "/filter.php", params: [c: category]) do
      {:ok, %{status: 200, body: %{"meals" => meals}}} when is_list(meals) ->
        {:ok, Enum.map(meals, &parse_meal/1)}

      {:ok, %{status: 200, body: %{"meals" => nil}}} ->
        {:ok, []}

      {:ok, %{status: status}} ->
        {:error, "API returned status #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Parse a meal from the API response into our internal format
  defp parse_meal(meal) do
    %{
      external_id: meal["idMeal"],
      name: meal["strMeal"],
      category: meal["strCategory"],
      area: meal["strArea"],
      instructions: meal["strInstructions"],
      image_url: meal["strMealThumb"],
      youtube_url: meal["strYoutube"],
      source_url: meal["strSource"],
      ingredients: parse_ingredients(meal),
      tags: parse_tags(meal["strTags"])
    }
  end

  # Parse ingredients from the meal data
  # TheMealDB has up to 20 ingredient/measure pairs
  defp parse_ingredients(meal) do
    1..20
    |> Enum.map(fn i ->
      ingredient = meal["strIngredient#{i}"]
      measure = meal["strMeasure#{i}"]

      case {ingredient, measure} do
        {nil, _} ->
          nil

        {"", _} ->
          nil

        {ing, meas} when is_binary(ing) ->
          %{
            name: String.trim(ing),
            measure: if(is_binary(meas), do: String.trim(meas), else: "")
          }
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Parse comma-separated tags
  defp parse_tags(nil), do: []
  defp parse_tags(""), do: []

  defp parse_tags(tags) when is_binary(tags) do
    tags
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  @doc """
  Convert a TheMealDB meal to our Recipe attributes format.

  This maps the external API data to the shape expected by our Recipe resource.
  Note: TheMealDB doesn't provide prep_time or cook_time data, so these fields
  are left nil and should be filled in manually by users.
  """
  def to_recipe_attrs(meal) do
    %{
      name: meal.name,
      description: build_description(meal),
      instructions: meal.instructions,
      image_url: meal.image_url,
      source: meal.source_url || "TheMealDB",
      difficulty: :medium,
      servings: 4,
      is_favorite: false
    }
  end

  defp build_description(meal) do
    parts =
      [meal.category, meal.area]
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&(&1 == ""))

    case parts do
      [] -> nil
      parts -> Enum.join(parts, " · ")
    end
  end

  # Build Req client with base URL and optional test plug
  defp req(opts) do
    base_opts = [base_url: @base_url]

    # Disable retries in test mode to improve test performance
    # Retries cause slow 500 error tests due to exponential backoff
    base_opts = if Keyword.has_key?(opts, :plug) do
      Keyword.put(base_opts, :retry, false)
    else
      base_opts
    end

    Req.new(Keyword.merge(base_opts, opts))
  end
end
