defmodule GroceryPlannerWeb.SettingsLive do
  use GroceryPlannerWeb, :live_view

  on_mount {GroceryPlannerWeb.Auth, :require_authenticated_user}

  alias GroceryPlanner.Accounts
  alias GroceryPlanner.MealPlanning.Voting

  def mount(_params, _session, socket) do
    voting_active = Voting.voting_active?(socket.assigns.current_account.id, socket.assigns.current_user)

    socket = assign(socket, :current_scope, socket.assigns.current_account)
    account = Ash.load!(socket.assigns.current_account, [:memberships])
    memberships = Ash.load!(account.memberships, [:user])

    current_membership =
      Enum.find(memberships, fn m -> m.user_id == socket.assigns.current_user.id end)

    account_form =
      to_form(%{
        "name" => account.name,
        "timezone" => account.timezone
      })

    user_form =
      to_form(%{
        "name" => socket.assigns.current_user.name,
        "email" => to_string(socket.assigns.current_user.email)
      })

    invite_form = to_form(%{})

    {:ok,
     socket
     |> assign(:voting_active, voting_active)
     |> assign(:account_form, account_form)
     |> assign(:user_form, user_form)
     |> assign(:invite_form, invite_form)
     |> assign(:memberships, memberships)
     |> assign(:current_role, current_membership.role)
     |> assign(:show_invite_form, false)}
  end

  def handle_event("validate_account", %{"name" => name, "timezone" => timezone}, socket) do
    account_form = to_form(%{"name" => name, "timezone" => timezone})
    {:noreply, assign(socket, :account_form, account_form)}
  end

  def handle_event("update_account", %{"name" => name, "timezone" => timezone}, socket) do
    case Accounts.Account.update(socket.assigns.current_account, %{
           name: name,
           timezone: timezone
         }) do
      {:ok, account} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account updated successfully")
         |> assign(:current_account, account)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update account")}
    end
  end

  def handle_event("validate_user", %{"name" => name, "email" => email}, socket) do
    user_form = to_form(%{"name" => name, "email" => email})
    {:noreply, assign(socket, :user_form, user_form)}
  end

  def handle_event("update_user", %{"name" => name, "email" => email}, socket) do
    case Accounts.User.update(socket.assigns.current_user, %{name: name, email: email}) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile updated successfully")
         |> assign(:current_user, user)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update profile")}
    end
  end

  def handle_event("show_invite_form", _params, socket) do
    {:noreply, assign(socket, :show_invite_form, true)}
  end

  def handle_event("hide_invite_form", _params, socket) do
    {:noreply, assign(socket, :show_invite_form, false)}
  end

  def handle_event("validate_invitation", %{"email" => email, "role" => role}, socket) do
    invite_form = to_form(%{"email" => email, "role" => role})
    {:noreply, assign(socket, :invite_form, invite_form)}
  end

  def handle_event("send_invitation", %{"email" => email, "role" => role}, socket) do
    case Accounts.User.by_email(email) do
      {:ok, user} ->
        role_atom = String.to_existing_atom(role)

        case Accounts.AccountMembership.create(
               socket.assigns.current_account.id,
               user.id,
               %{role: role_atom}
             ) do
          {:ok, _membership} ->
            memberships =
              socket.assigns.current_account
              |> Ash.load!([:memberships])
              |> Map.get(:memberships)
              |> Ash.load!([:user])

            {:noreply,
             socket
             |> put_flash(:info, "Member added successfully")
             |> assign(:memberships, memberships)
             |> assign(:show_invite_form, false)
             |> assign(:invite_form, to_form(%{}))}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to add member")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "User with that email not found")}
    end
  end

  def handle_event("remove_member", %{"id" => id}, socket) do
    membership =
      Enum.find(socket.assigns.memberships, fn m -> m.id == id end)

    case Accounts.AccountMembership.destroy(membership) do
      :ok ->
        memberships =
          socket.assigns.current_account
          |> Ash.load!([:memberships])
          |> Map.get(:memberships)
          |> Ash.load!([:user])

        {:noreply,
         socket
         |> put_flash(:info, "Member removed successfully")
         |> assign(:memberships, memberships)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove member")}
    end
  end
end
