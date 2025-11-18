defmodule GroceryPlanner.TheMealDBStubs do
  @moduledoc """
  Test stubs for TheMealDB API using Req.Test.

  Usage in tests:
      Req.Test.stub(TheMealDB, &TheMealDBStubs.search_chicken/1)
      TheMealDB.search_by_name("chicken", plug: {Req.Test, TheMealDB})
  """

  @doc """
  Stub for searching chicken recipes.
  Returns a minimal but realistic response.
  """
  def search_chicken(conn) do
    Req.Test.json(conn, %{
      "meals" => [
        %{
          "idMeal" => "52940",
          "strMeal" => "Brown Stew Chicken",
          "strCategory" => "Chicken",
          "strArea" => "Jamaican",
          "strInstructions" => "Squeeze lime over chicken and rub well...",
          "strMealThumb" => "https://www.themealdb.com/images/media/meals/sypxpx1515365095.jpg",
          "strYoutube" => "",
          "strSource" => "",
          "strTags" => "Stew",
          "strIngredient1" => "Chicken",
          "strIngredient2" => "Tomato",
          "strIngredient3" => "Onions",
          "strIngredient4" => "",
          "strMeasure1" => "1 whole",
          "strMeasure2" => "2",
          "strMeasure3" => "2 chopped",
          "strMeasure4" => ""
        },
        %{
          "idMeal" => "52795",
          "strMeal" => "Chicken Handi",
          "strCategory" => "Chicken",
          "strArea" => "Indian",
          "strInstructions" => "Take a large pot or wok...",
          "strMealThumb" => "https://www.themealdb.com/images/media/meals/wyxwsp1486979827.jpg",
          "strYoutube" => "",
          "strSource" => "",
          "strTags" => nil,
          "strIngredient1" => "Chicken",
          "strIngredient2" => "Onion",
          "strIngredient3" => "Tomatoes",
          "strIngredient4" => "Garlic",
          "strIngredient5" => "",
          "strMeasure1" => "1.2 kg",
          "strMeasure2" => "5 thinly sliced",
          "strMeasure3" => "2 finely chopped",
          "strMeasure4" => "8 cloves chopped",
          "strMeasure5" => ""
        }
      ]
    })
  end

  @doc """
  Stub for empty search results.
  """
  def search_empty(conn) do
    Req.Test.json(conn, %{"meals" => nil})
  end

  @doc """
  Stub for getting a specific meal by ID.
  """
  def get_meal_by_id(conn) do
    Req.Test.json(conn, %{
      "meals" => [
        %{
          "idMeal" => "52940",
          "strMeal" => "Brown Stew Chicken",
          "strCategory" => "Chicken",
          "strArea" => "Jamaican",
          "strInstructions" => "Full instructions here...",
          "strMealThumb" => "https://www.themealdb.com/images/media/meals/sypxpx1515365095.jpg",
          "strYoutube" => "https://www.youtube.com/watch?v=1",
          "strSource" => "https://example.com/recipe",
          "strTags" => "Stew,Comfort",
          "strIngredient1" => "Chicken",
          "strIngredient2" => "Tomato",
          "strIngredient3" => "Onions",
          "strIngredient4" => "Garlic",
          "strIngredient5" => "Thyme",
          "strIngredient6" => "",
          "strMeasure1" => "1 whole",
          "strMeasure2" => "2",
          "strMeasure3" => "2 chopped",
          "strMeasure4" => "4 cloves",
          "strMeasure5" => "2 sprigs",
          "strMeasure6" => ""
        }
      ]
    })
  end

  @doc """
  Stub for meal not found.
  """
  def get_meal_not_found(conn) do
    Req.Test.json(conn, %{"meals" => nil})
  end

  @doc """
  Stub for random meal.
  """
  def random_meal(conn) do
    Req.Test.json(conn, %{
      "meals" => [
        %{
          "idMeal" => "52771",
          "strMeal" => "Spicy Arrabiata Penne",
          "strCategory" => "Vegetarian",
          "strArea" => "Italian",
          "strInstructions" => "Bring a large pot of water to a boil...",
          "strMealThumb" => "https://www.themealdb.com/images/media/meals/ustsqw1468250014.jpg",
          "strYoutube" => "https://www.youtube.com/watch?v=1",
          "strSource" => "",
          "strTags" => "Pasta,Curry",
          "strIngredient1" => "penne rigate",
          "strIngredient2" => "olive oil",
          "strIngredient3" => "garlic",
          "strIngredient4" => "chopped tomatoes",
          "strIngredient5" => "red chile flakes",
          "strIngredient6" => "italian seasoning",
          "strIngredient7" => "basil",
          "strIngredient8" => "Parmigiano-Reggiano",
          "strIngredient9" => "",
          "strMeasure1" => "1 pound",
          "strMeasure2" => "1/4 cup",
          "strMeasure3" => "3 cloves",
          "strMeasure4" => "1 tin",
          "strMeasure5" => "1/2 teaspoon",
          "strMeasure6" => "1/2 teaspoon",
          "strMeasure7" => "6 leaves",
          "strMeasure8" => "spinkling",
          "strMeasure9" => ""
        }
      ]
    })
  end

  @doc """
  Stub for API error (500 status).
  """
  def api_error(conn) do
    conn
    |> Plug.Conn.put_status(500)
    |> Req.Test.text("Internal Server Error")
  end

  @doc """
  Stub for categories list.
  """
  def list_categories(conn) do
    Req.Test.json(conn, %{
      "categories" => [
        %{"idCategory" => "1", "strCategory" => "Beef"},
        %{"idCategory" => "2", "strCategory" => "Chicken"},
        %{"idCategory" => "3", "strCategory" => "Dessert"}
      ]
    })
  end

  @doc """
  Stub for filter by category.
  """
  def filter_by_chicken(conn) do
    search_chicken(conn)
  end
end
