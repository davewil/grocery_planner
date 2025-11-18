defmodule GroceryPlannerWeb.RecipeFormLive do
  use GroceryPlannerWeb, :live_view

  on_mount {GroceryPlannerWeb.Auth, :require_authenticated_user}

  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(:current_scope, socket.assigns.current_account)

    case socket.assigns.live_action do
      :new ->
        form = to_form(%{}, as: :recipe)
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
              "is_favorite" => recipe.is_favorite
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
      |> Map.put("is_favorite", Map.get(recipe_params, "is_favorite") == "true")
      |> convert_empty_to_nil(["prep_time_minutes", "cook_time_minutes", "image_url", "source"])

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

  defp convert_empty_to_nil(params, keys) do
    Enum.reduce(keys, params, fn key, acc ->
      case Map.get(acc, key) do
        "" -> Map.put(acc, key, nil)
        _other -> acc
      end
    end)
  end
end
