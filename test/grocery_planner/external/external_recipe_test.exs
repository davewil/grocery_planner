defmodule GroceryPlanner.External.ExternalRecipeTest do
  use ExUnit.Case, async: true
  alias GroceryPlanner.External
  alias GroceryPlanner.External.ExternalRecipe
  alias GroceryPlanner.External.TheMealDB

  describe "search_recipes/1" do
    test "returns ExternalRecipe structs when API returns results" do
      Req.Test.stub(TheMealDB, fn conn ->
        assert conn.request_path == "/api/json/v1/1/search.php"
        assert conn.query_params["s"] == "Test"

        Req.Test.json(conn, %{
          "meals" => [
            %{
              "idMeal" => "123",
              "strMeal" => "Test Recipe",
              "strCategory" => "Chicken",
              "strArea" => "American",
              "strInstructions" => "Cook it",
              "strMealThumb" => "https://example.com/image.jpg",
              "strYoutube" => nil,
              "strSource" => nil,
              "strTags" => "dinner",
              "strIngredient1" => "",
              "strMeasure1" => ""
            }
          ]
        })
      end)

      assert {:ok, recipes} = External.search_recipes("Test")
      assert length(recipes) == 1
      assert hd(recipes).name == "Test Recipe"
    end
  end

  describe "random_recipe/0" do
    test "returns a random recipe from the external API" do
      Req.Test.stub(TheMealDB, fn conn ->
        assert conn.request_path == "/api/json/v1/1/random.php"

        Req.Test.json(conn, %{
          "meals" => [
            %{
              "idMeal" => "12345",
              "strMeal" => "Random Test Recipe",
              "strCategory" => "Beef",
              "strArea" => "British",
              "strInstructions" => "Cook it.",
              "strMealThumb" => "http://example.com/image.jpg",
              "strTags" => nil,
              "strYoutube" => nil,
              "strSource" => nil
            }
          ]
        })
      end)

      assert {:ok, [recipe]} = External.random_recipe()
      assert recipe.external_id == "12345"
      assert recipe.name == "Random Test Recipe"
    end

    test "handles API errors" do
      Req.Test.stub(TheMealDB, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, _} = External.random_recipe()
    end
  end

  describe "recipes_by_category/1" do
    test "returns recipes for a given category" do
      Req.Test.stub(TheMealDB, fn conn ->
        assert conn.request_path == "/api/json/v1/1/filter.php"
        assert conn.query_params["c"] == "Seafood"

        Req.Test.json(conn, %{
          "meals" => [
            %{"idMeal" => "1", "strMeal" => "Meal 1", "strMealThumb" => "thumb1.jpg"},
            %{"idMeal" => "2", "strMeal" => "Meal 2", "strMealThumb" => "thumb2.jpg"}
          ]
        })
      end)

      assert {:ok, recipes} = External.recipes_by_category("Seafood")
      assert length(recipes) == 2
      assert hd(recipes).name == "Meal 1"
    end

    test "handles API errors" do
      Req.Test.stub(TheMealDB, fn conn ->
        Plug.Conn.send_resp(conn, 500, "Internal Server Error")
      end)

      assert {:error, _} = External.recipes_by_category("Invalid")
    end
  end

  describe "ExternalRecipe struct" do
    test "can be created with required attributes" do
      recipe = %ExternalRecipe{
        external_id: "123",
        name: "Test Recipe",
        category: "Chicken",
        area: "American",
        instructions: "Cook it",
        image_url: "https://example.com/image.jpg",
        youtube_url: nil,
        source_url: nil,
        ingredients: [
          %{name: "Chicken", measure: "1 lb"}
        ],
        tags: ["dinner"]
      }

      assert recipe.external_id == "123"
      assert recipe.name == "Test Recipe"
      assert length(recipe.ingredients) == 1
      assert recipe.tags == ["dinner"]
    end

    test "has default empty lists for ingredients and tags" do
      recipe = %ExternalRecipe{
        external_id: "123",
        name: "Test"
      }

      assert recipe.ingredients == []
      assert recipe.tags == []
    end
  end

  describe "resource metadata" do
    test "uses Simple data layer" do
      info = Ash.Resource.Info.data_layer(ExternalRecipe)
      assert info == Ash.DataLayer.Simple
    end

    test "has correct domain" do
      domain = Ash.Resource.Info.domain(ExternalRecipe)
      assert domain == GroceryPlanner.External
    end

    test "has search action" do
      action = Ash.Resource.Info.action(ExternalRecipe, :search)
      assert action != nil
      assert action.type == :read

      # Check it has query argument
      query_arg = Enum.find(action.arguments, fn arg -> arg.name == :query end)
      assert query_arg != nil
      assert query_arg.type == Ash.Type.String
    end

    test "has by_id action" do
      action = Ash.Resource.Info.action(ExternalRecipe, :by_id)
      assert action != nil
      assert action.type == :read
      assert action.get? == true

      # Check it has id argument
      id_arg = Enum.find(action.arguments, fn arg -> arg.name == :id end)
      assert id_arg != nil
      assert id_arg.type == Ash.Type.String
    end

    test "has random action" do
      action = Ash.Resource.Info.action(ExternalRecipe, :random)
      assert action != nil
      assert action.type == :read
    end

    test "has by_category action" do
      action = Ash.Resource.Info.action(ExternalRecipe, :by_category)
      assert action != nil
      assert action.type == :read

      # Check it has category argument
      category_arg = Enum.find(action.arguments, fn arg -> arg.name == :category end)
      assert category_arg != nil
      assert category_arg.type == Ash.Type.String
    end

    test "has recipe_attrs calculation" do
      calc = Ash.Resource.Info.calculation(ExternalRecipe, :recipe_attrs)
      assert calc != nil
      assert calc.type == Ash.Type.Map
    end

    test "has all required attributes" do
      attributes = Ash.Resource.Info.attributes(ExternalRecipe)
      attribute_names = Enum.map(attributes, & &1.name)

      assert :external_id in attribute_names
      assert :name in attribute_names
      assert :category in attribute_names
      assert :area in attribute_names
      assert :instructions in attribute_names
      assert :image_url in attribute_names
      assert :youtube_url in attribute_names
      assert :source_url in attribute_names
      assert :ingredients in attribute_names
      assert :tags in attribute_names
    end

    test "external_id is primary key" do
      external_id_attr = Ash.Resource.Info.attribute(ExternalRecipe, :external_id)
      assert external_id_attr.primary_key? == true
    end
  end

  describe "domain code interface" do
    test "External domain has search_recipes function" do
      functions = External.__info__(:functions)
      assert {:search_recipes, 1} in functions
    end

    test "External domain has get_external_recipe function" do
      functions = External.__info__(:functions)
      assert {:get_external_recipe, 1} in functions
    end

    test "External domain has random_recipe function" do
      functions = External.__info__(:functions)
      assert {:random_recipe, 0} in functions
    end

    test "External domain has recipes_by_category function" do
      functions = External.__info__(:functions)
      assert {:recipes_by_category, 1} in functions
    end
  end
end
