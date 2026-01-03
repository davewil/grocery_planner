defmodule GroceryPlannerWeb.RecipeShowLive do
  use GroceryPlannerWeb, :live_view
  import GroceryPlannerWeb.UIComponents
  require Logger

  on_mount {GroceryPlannerWeb.Auth, :require_authenticated_user}

  alias GroceryPlanner.MealPlanning.Voting

  def mount(%{"id" => id}, _session, socket) do
    case load_recipe(socket, id) do
      {:ok, socket} ->
        {:ok, socket}

      {:error, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Recipe not found")
          |> push_navigate(to: "/recipes")

        {:ok, socket}
    end
  end

  def handle_event("toggle_favorite", _, socket) do
    Logger.info("Toggle favorite clicked for recipe #{socket.assigns.recipe.id}")
    Logger.info("Current favorite status: #{socket.assigns.recipe.is_favorite}")

    case GroceryPlanner.Recipes.update_recipe(
           socket.assigns.recipe,
           %{is_favorite: !socket.assigns.recipe.is_favorite},
           actor: socket.assigns.current_user,
           tenant: socket.assigns.current_account.id
         ) do
      {:ok, updated_recipe} ->
        Logger.info(
          "Successfully updated recipe, new favorite status: #{updated_recipe.is_favorite}"
        )

        case load_recipe(socket, socket.assigns.recipe.id) do
          {:ok, updated_socket} ->
            {:noreply, updated_socket}

          {:error, reason} ->
            Logger.error("Failed to reload recipe: #{inspect(reason)}")
            {:noreply, put_flash(socket, :error, "Failed to reload recipe")}
        end

      {:error, error} ->
        Logger.error("Failed to update favorite status: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to update favorite status")}
    end
  end

  def handle_event("edit_recipe", _, socket) do
    {:noreply, push_navigate(socket, to: "/recipes/#{socket.assigns.recipe.id}/edit")}
  end

  def handle_event("delete_recipe", _, socket) do
    result =
      GroceryPlanner.Recipes.destroy_recipe(
        socket.assigns.recipe,
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id
      )

    case result do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Recipe deleted successfully")
          |> push_navigate(to: "/recipes")

        {:noreply, socket}

      :ok ->
        socket =
          socket
          |> put_flash(:info, "Recipe deleted successfully")
          |> push_navigate(to: "/recipes")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete recipe")}
    end
  end

  def handle_event("add_ingredient", _, socket) do
    {:noreply, push_navigate(socket, to: "/recipes/#{socket.assigns.recipe.id}/edit")}
  end

  defp load_recipe(socket, id) do
    account_id = socket.assigns.current_account.id
    user = socket.assigns.current_user
    voting_active = Voting.voting_active?(account_id, user)

    case GroceryPlanner.Recipes.get_recipe(id, actor: user, tenant: account_id) do
      {:ok, recipe} ->
        recipe_with_ingredients =
          recipe
          |> Ash.load!(:recipe_ingredients, actor: user, tenant: account_id)

        ingredients =
          case recipe_with_ingredients.recipe_ingredients do
            %Ash.NotLoaded{} ->
              []

            ingredients when is_list(ingredients) ->
              ingredients
              |> Enum.map(fn ingredient ->
                Ash.load!(ingredient, :grocery_item, actor: user, tenant: account_id)
              end)
              |> Enum.sort_by(& &1.sort_order)

            _ ->
              []
          end

        socket =
          socket
          |> assign(:current_scope, socket.assigns.current_account)
          |> assign(:voting_active, voting_active)
          |> assign(:recipe, recipe_with_ingredients)
          |> assign(:ingredients, ingredients)

        {:ok, socket}

      {:error, _} ->
        {:error, :not_found}
    end
  end
end
