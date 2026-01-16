defmodule GroceryPlannerWeb.RecipeFormLive do
  use GroceryPlannerWeb, :live_view

  on_mount {GroceryPlannerWeb.Auth, :require_authenticated_user}

  alias GroceryPlanner.MealPlanning.Voting

  def mount(params, _session, socket) do
    voting_active =
      Voting.voting_active?(socket.assigns.current_account.id, socket.assigns.current_user)

    parent_recipe = load_parent_recipe(socket, params["parent_recipe_id"])

    socket =
      socket
      |> assign(:current_scope, socket.assigns.current_account)
      |> assign(:voting_active, voting_active)
      |> assign(:parent_recipe, parent_recipe)

    case socket.assigns.live_action do
      :new ->
        initial_data =
          if parent_recipe do
            %{"is_follow_up" => true, "parent_recipe_id" => parent_recipe.id}
          else
            %{}
          end

        form = to_form(initial_data, as: :recipe)
        {:ok, assign(socket, form: form, recipe: nil)}

      :edit ->
        case load_recipe(socket, params["id"]) do
          {:ok, recipe} ->
            recipe_data = %{
              "name" => recipe.name,
              "description" => recipe.description,
              "instructions" => recipe.instructions,
              "prep_time_minutes" => recipe.prep_time_minutes,
              "cook_time_minutes" => recipe.cook_time_minutes,
              "servings" => recipe.servings,
              "difficulty" => to_string(recipe.difficulty),
              "image_url" => recipe.image_url,
              "source" => recipe.source,
              "is_favorite" => recipe.is_favorite,
              "cuisine" => recipe.cuisine,
              "dietary_needs" => recipe.dietary_needs || []
            }

            form = to_form(recipe_data, as: :recipe)
            {:ok, assign(socket, form: form, recipe: recipe)}

          {:error, :not_found} ->
            socket =
              socket
              |> put_flash(:error, "Recipe not found")
              |> push_navigate(to: "/recipes")

            {:ok, socket}
        end
    end
  end

  def handle_event("save", %{"recipe" => recipe_params}, socket) do
    account_id = socket.assigns.current_account.id

    recipe_params =
      recipe_params
      |> Map.put("is_favorite", Map.has_key?(recipe_params, "is_favorite"))
      |> convert_empty_to_nil([
        "prep_time_minutes",
        "cook_time_minutes",
        "image_url",
        "source",
        "cuisine"
      ])
      |> convert_dietary_needs()

    # Include chain fields if creating a follow-up
    recipe_params =
      if socket.assigns.parent_recipe && socket.assigns.live_action == :new do
        recipe_params
        |> Map.put("is_follow_up", true)
        |> Map.put("parent_recipe_id", socket.assigns.parent_recipe.id)
      else
        recipe_params
      end

    result =
      case socket.assigns.live_action do
        :new ->
          GroceryPlanner.Recipes.create_recipe(
            account_id,
            recipe_params,
            authorize?: false,
            tenant: account_id
          )

        :edit ->
          GroceryPlanner.Recipes.update_recipe(
            socket.assigns.recipe,
            recipe_params,
            actor: socket.assigns.current_user,
            tenant: account_id
          )
      end

    case result do
      {:ok, recipe} ->
        socket =
          socket
          |> put_flash(:info, "Recipe saved successfully")
          |> push_navigate(to: "/recipes/#{recipe.id}")

        {:noreply, socket}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to save recipe")}
    end
  end

  def handle_event("toggle_favorite", _, socket) do
    # Toggle the favorite value in the form
    current_value = socket.assigns.form[:is_favorite].value || false
    new_value = !current_value

    # Get current form data
    form_data =
      socket.assigns.form.source
      |> Map.put("is_favorite", new_value)

    # Update the form
    form = to_form(form_data, as: :recipe)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("cancel", _, socket) do
    path =
      case socket.assigns.live_action do
        :new -> "/recipes"
        :edit -> "/recipes/#{socket.assigns.recipe.id}"
      end

    {:noreply, push_navigate(socket, to: path)}
  end

  defp load_recipe(socket, id) do
    account_id = socket.assigns.current_account.id
    user = socket.assigns.current_user

    case GroceryPlanner.Recipes.get_recipe(id, actor: user, tenant: account_id) do
      {:ok, recipe} -> {:ok, recipe}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp load_parent_recipe(_socket, nil), do: nil

  defp load_parent_recipe(socket, parent_id) do
    case GroceryPlanner.Recipes.get_recipe(parent_id,
           actor: socket.assigns.current_user,
           tenant: socket.assigns.current_account.id
         ) do
      {:ok, recipe} -> recipe
      {:error, _} -> nil
    end
  end

  defp convert_empty_to_nil(params, keys) do
    Enum.reduce(keys, params, fn key, acc ->
      case Map.get(acc, key) do
        "" -> Map.put(acc, key, nil)
        _other -> acc
      end
    end)
  end

  defp convert_dietary_needs(params) do
    case Map.get(params, "dietary_needs") do
      nil ->
        params

      needs when is_list(needs) ->
        atoms =
          needs
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(&String.to_existing_atom/1)

        Map.put(params, "dietary_needs", atoms)

      _ ->
        params
    end
  end

  @doc false
  def dietary_needs_options do
    [
      {"Vegan", :vegan},
      {"Vegetarian", :vegetarian},
      {"Pescatarian", :pescatarian},
      {"Gluten-Free", :gluten_free},
      {"Dairy-Free", :dairy_free},
      {"Nut-Free", :nut_free},
      {"Halal", :halal},
      {"Kosher", :kosher},
      {"Keto", :keto},
      {"Paleo", :paleo}
    ]
  end
end
