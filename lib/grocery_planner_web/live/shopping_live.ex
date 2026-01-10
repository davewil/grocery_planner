defmodule GroceryPlannerWeb.ShoppingLive do
  use GroceryPlannerWeb, :live_view
  import GroceryPlannerWeb.UIComponents
  require Logger
  require Ash.Query

  on_mount({GroceryPlannerWeb.Auth, :require_authenticated_user})

  alias GroceryPlanner.MealPlanning.Voting

  def mount(_params, _session, socket) do
    voting_active =
      Voting.voting_active?(socket.assigns.current_account.id, socket.assigns.current_user)

    socket = assign(socket, :current_scope, socket.assigns.current_account)

    socket =
      socket
      |> assign(:voting_active, voting_active)
      |> assign(:show_create_modal, false)
      |> assign(:show_generate_modal, false)
      |> assign(:show_add_item_modal, false)
      |> assign(:selected_list, nil)
      |> assign(:start_date, Date.utc_today() |> Date.to_iso8601())
      |> assign(:end_date, Date.utc_today() |> Date.add(7) |> Date.to_iso8601())
      |> assign(:new_list_name, "")
      |> assign(:new_item_name, "")
      |> assign(:new_item_quantity, "1")
      |> assign(:new_item_unit, "")
      |> load_shopping_lists()

    {:ok, socket}
  end

  def handle_event("show_create_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, true)}
  end

  def handle_event("hide_create_modal", _params, socket) do
    {:noreply, assign(socket, show_create_modal: false, new_list_name: "")}
  end

  def handle_event("show_generate_modal", _params, socket) do
    today = Date.utc_today()
    week_end = Date.add(today, 7)

    socket =
      socket
      |> assign(:show_generate_modal, true)
      |> assign(:start_date, Date.to_iso8601(today))
      |> assign(:end_date, Date.to_iso8601(week_end))

    {:noreply, socket}
  end

  def handle_event("hide_generate_modal", _params, socket) do
    {:noreply, assign(socket, :show_generate_modal, false)}
  end

  def handle_event("create_list", %{"name" => name}, socket) do
    case GroceryPlanner.Shopping.create_shopping_list(
           socket.assigns.current_account.id,
           %{name: name},
           tenant: socket.assigns.current_account.id,
           actor: socket.assigns.current_user
         ) do
      {:ok, _list} ->
        socket =
          socket
          |> put_flash(:info, "Shopping list created successfully")
          |> assign(:show_create_modal, false)
          |> assign(:new_list_name, "")
          |> load_shopping_lists()

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to create shopping list: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to create shopping list")}
    end
  end

  def handle_event(
        "generate_list",
        %{"start_date" => start_date_str, "end_date" => end_date_str, "name" => name},
        socket
      ) do
    start_date = Date.from_iso8601!(start_date_str)
    end_date = Date.from_iso8601!(end_date_str)

    case GroceryPlanner.Shopping.generate_shopping_list_from_meal_plans(
           socket.assigns.current_account.id,
           start_date,
           end_date,
           %{name: name},
           tenant: socket.assigns.current_account.id,
           actor: socket.assigns.current_user
         ) do
      {:ok, _list} ->
        socket =
          socket
          |> put_flash(:info, "Shopping list generated from meal plans")
          |> assign(:show_generate_modal, false)
          |> load_shopping_lists()

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to generate shopping list: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to generate shopping list")}
    end
  end

  def handle_event("select_list", %{"id" => id}, socket) do
    {:ok, list} =
      GroceryPlanner.Shopping.get_shopping_list(
        id,
        tenant: socket.assigns.current_account.id,
        actor: socket.assigns.current_user,
        load: [:items, :total_items, :checked_items, :progress_percentage]
      )

    {:noreply, assign(socket, :selected_list, list)}
  end

  def handle_event("back_to_lists", _params, socket) do
    {:noreply, assign(socket, :selected_list, nil)}
  end

  def handle_event("delete_list", %{"id" => id}, socket) do
    {:ok, list} =
      GroceryPlanner.Shopping.get_shopping_list(
        id,
        tenant: socket.assigns.current_account.id,
        actor: socket.assigns.current_user
      )

    case GroceryPlanner.Shopping.destroy_shopping_list(list,
           tenant: socket.assigns.current_account.id,
           actor: socket.assigns.current_user
         ) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Shopping list deleted")
          |> assign(:selected_list, nil)
          |> load_shopping_lists()

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to delete shopping list: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to delete shopping list")}
    end
  end

  def handle_event("toggle_item", %{"id" => id}, socket) do
    {:ok, item} =
      GroceryPlanner.Shopping.get_shopping_list_item(
        id,
        tenant: socket.assigns.current_account.id,
        actor: socket.assigns.current_user
      )

    case GroceryPlanner.Shopping.toggle_shopping_list_item_check(item,
           tenant: socket.assigns.current_account.id,
           actor: socket.assigns.current_user
         ) do
      {:ok, _item} ->
        socket =
          if socket.assigns.selected_list do
            {:ok, list} =
              GroceryPlanner.Shopping.get_shopping_list(
                socket.assigns.selected_list.id,
                tenant: socket.assigns.current_account.id,
                actor: socket.assigns.current_user,
                load: [:items, :total_items, :checked_items, :progress_percentage]
              )

            assign(socket, :selected_list, list)
          else
            socket
          end

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to toggle item: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to update item")}
    end
  end

  def handle_event("show_add_item_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_add_item_modal, true)
      |> assign(:new_item_name, "")
      |> assign(:new_item_quantity, "1")
      |> assign(:new_item_unit, "")

    {:noreply, socket}
  end

  def handle_event("hide_add_item_modal", _params, socket) do
    {:noreply, assign(socket, :show_add_item_modal, false)}
  end

  def handle_event("prevent_close", _params, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "add_item",
        %{"name" => name, "quantity" => quantity_str, "unit" => unit} = params,
        socket
      ) do
    quantity = Decimal.new(quantity_str)

    attrs = %{
      shopping_list_id: socket.assigns.selected_list.id,
      name: name,
      quantity: quantity,
      unit: unit
    }

    attrs =
      if params["estimated_price"] && params["estimated_price"] != "" do
        currency = socket.assigns.current_account.currency || "USD"
        Map.put(attrs, :estimated_price, %{amount: params["estimated_price"], currency: currency})
      else
        attrs
      end

    case GroceryPlanner.Shopping.create_shopping_list_item(
           socket.assigns.current_account.id,
           attrs,
           tenant: socket.assigns.current_account.id,
           actor: socket.assigns.current_user
         ) do
      {:ok, _item} ->
        {:ok, list} =
          GroceryPlanner.Shopping.get_shopping_list(
            socket.assigns.selected_list.id,
            tenant: socket.assigns.current_account.id,
            actor: socket.assigns.current_user,
            load: [:items, :total_items, :checked_items, :progress_percentage]
          )

        socket =
          socket
          |> put_flash(:info, "Item added")
          |> assign(:show_add_item_modal, false)
          |> assign(:selected_list, list)

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to add item: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to add item")}
    end
  end

  def handle_event("delete_item", %{"id" => id}, socket) do
    {:ok, item} =
      GroceryPlanner.Shopping.get_shopping_list_item(
        id,
        tenant: socket.assigns.current_account.id,
        actor: socket.assigns.current_user
      )

    case GroceryPlanner.Shopping.destroy_shopping_list_item(item,
           tenant: socket.assigns.current_account.id,
           actor: socket.assigns.current_user
         ) do
      :ok ->
        {:ok, list} =
          GroceryPlanner.Shopping.get_shopping_list(
            socket.assigns.selected_list.id,
            tenant: socket.assigns.current_account.id,
            actor: socket.assigns.current_user,
            load: [:items, :total_items, :checked_items, :progress_percentage]
          )

        socket =
          socket
          |> put_flash(:info, "Item removed")
          |> assign(:selected_list, list)

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to delete item: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to remove item")}
    end
  end

  defp load_shopping_lists(socket) do
    {:ok, lists} =
      GroceryPlanner.Shopping.list_shopping_lists(
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_account.id,
        query:
          GroceryPlanner.Shopping.ShoppingList
          |> Ash.Query.filter(or: [status: :active, status: :completed])
          |> Ash.Query.sort(updated_at: :desc)
          |> Ash.Query.load([:total_items, :checked_items, :progress_percentage])
      )

    assign(socket, :shopping_lists, lists)
  end
end
