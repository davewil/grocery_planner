defmodule GroceryPlannerWeb.FamilyLive do
  use GroceryPlannerWeb, :live_view
  import GroceryPlannerWeb.UIComponents

  on_mount {GroceryPlannerWeb.Auth, :require_authenticated_user}

  alias GroceryPlanner.Family
  alias GroceryPlanner.Recipes
  alias GroceryPlanner.MealPlanning.Voting

  def mount(_params, _session, socket) do
    voting_active =
      Voting.voting_active?(socket.assigns.current_account.id, socket.assigns.current_user)

    socket =
      socket
      |> assign(:current_scope, socket.assigns.current_account)
      |> assign(:voting_active, voting_active)
      |> assign(:adding_member, false)
      |> assign(:editing_member, nil)
      |> assign(:new_member_name, "")
      |> assign(:edit_member_name, "")
      |> assign(:recipe_search, "")
      |> load_data()

    {:ok, socket}
  end

  # -- Member CRUD events --

  def handle_event("show_add_member", _, socket) do
    {:noreply, assign(socket, adding_member: true, new_member_name: "")}
  end

  def handle_event("cancel_add_member", _, socket) do
    {:noreply, assign(socket, adding_member: false, new_member_name: "")}
  end

  def handle_event("save_member", %{"name" => name}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply, put_flash(socket, :error, "Name cannot be blank")}
    else
      account = socket.assigns.current_account
      user = socket.assigns.current_user

      case Family.create_family_member(account.id, %{name: name},
             actor: user,
             tenant: account.id
           ) do
        {:ok, _member} ->
          socket =
            socket
            |> assign(:adding_member, false)
            |> assign(:new_member_name, "")
            |> load_data()
            |> put_flash(:info, "#{name} added to the family")

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to add family member")}
      end
    end
  end

  def handle_event("edit_member", %{"id" => id}, socket) do
    member = Enum.find(socket.assigns.family_members, &(&1.id == id))

    {:noreply,
     assign(socket,
       editing_member: id,
       edit_member_name: (member && member.name) || ""
     )}
  end

  def handle_event("cancel_edit_member", _, socket) do
    {:noreply, assign(socket, editing_member: nil, edit_member_name: "")}
  end

  def handle_event("update_member", %{"member_id" => id, "name" => name}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply, put_flash(socket, :error, "Name cannot be blank")}
    else
      member = Enum.find(socket.assigns.family_members, &(&1.id == id))
      user = socket.assigns.current_user
      account = socket.assigns.current_account

      case Family.update_family_member(member, %{name: name},
             actor: user,
             tenant: account.id
           ) do
        {:ok, _} ->
          socket =
            socket
            |> assign(:editing_member, nil)
            |> assign(:edit_member_name, "")
            |> load_data()

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update member")}
      end
    end
  end

  def handle_event("delete_member", %{"id" => id}, socket) do
    member = Enum.find(socket.assigns.family_members, &(&1.id == id))
    user = socket.assigns.current_user
    account = socket.assigns.current_account

    case Family.destroy_family_member(member, actor: user, tenant: account.id) do
      {:ok, _} ->
        socket =
          socket
          |> load_data()
          |> put_flash(:info, "#{member.name} removed from the family")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove member")}
    end
  end

  # -- Preference toggle --

  def handle_event(
        "toggle_preference",
        %{"recipe-id" => recipe_id, "member-id" => member_id},
        socket
      ) do
    account = socket.assigns.current_account
    user = socket.assigns.current_user
    matrix = socket.assigns.preference_matrix
    current = Map.get(matrix, {recipe_id, member_id})
    opts = [actor: user, tenant: account.id]

    result =
      case current do
        nil ->
          # nil -> liked
          Family.set_recipe_preference(
            account.id,
            member_id,
            recipe_id,
            %{preference: :liked},
            opts
          )

        {:liked, _id} ->
          # liked -> disliked
          Family.set_recipe_preference(
            account.id,
            member_id,
            recipe_id,
            %{preference: :disliked},
            opts
          )

        {:disliked, pref_id} ->
          # disliked -> clear (use stored ID, no extra query)
          pref = %GroceryPlanner.Family.RecipePreference{id: pref_id}
          Family.destroy_recipe_preference(pref, opts)
      end

    case result do
      {:ok, _} -> {:noreply, load_data(socket)}
      :ok -> {:noreply, load_data(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to update preference")}
    end
  end

  # -- Recipe search --

  def handle_event("search_recipes", %{"search" => search}, socket) do
    {:noreply, assign(socket, recipe_search: search) |> filter_recipes()}
  end

  # -- Data loading --

  defp load_data(socket) do
    account = socket.assigns.current_account
    user = socket.assigns.current_user

    family_members =
      Family.list_family_members!(actor: user, tenant: account.id)
      |> Enum.sort_by(& &1.name)

    all_recipes =
      Recipes.list_recipes_sorted!(actor: user, tenant: account.id)

    recipe_ids = Enum.map(all_recipes, & &1.id)

    preferences =
      if recipe_ids != [] do
        Family.list_preferences_for_recipes!(recipe_ids, actor: user, tenant: account.id)
      else
        []
      end

    preference_matrix =
      Map.new(preferences, fn pref ->
        {{pref.recipe_id, pref.family_member_id}, {pref.preference, pref.id}}
      end)

    socket
    |> assign(:family_members, family_members)
    |> assign(:all_recipes, all_recipes)
    |> assign(:preference_matrix, preference_matrix)
    |> filter_recipes()
  end

  defp filter_recipes(socket) do
    search = String.downcase(socket.assigns.recipe_search || "")
    all_recipes = socket.assigns.all_recipes

    filtered =
      if search == "" do
        all_recipes
      else
        Enum.filter(all_recipes, fn recipe ->
          String.contains?(String.downcase(recipe.name), search)
        end)
      end

    assign(socket, :recipes, filtered)
  end
end
