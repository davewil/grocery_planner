defmodule GroceryPlannerWeb.Auth.SignUpLive do
  use GroceryPlannerWeb, :live_view
  require Logger

  alias GroceryPlanner.Accounts

  def mount(_params, _session, socket) do
    form = to_form(%{}, as: :user)
    {:ok, assign(socket, form: form)}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    {:noreply, assign(socket, form: to_form(user_params, as: :user))}
  end

  def handle_event("sign_up", %{"user" => user_params}, socket) do
    case create_user_with_account(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully!")
         |> push_navigate(to: "/sign-in")}

      {:error, error} ->
        Logger.error("Failed to create account: #{inspect(error)}")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to create account. Please try again.")
         |> assign(form: to_form(user_params, as: :user))}
    end
  end

  defp create_user_with_account(params) do
    %{"email" => email, "name" => name, "password" => password, "account_name" => account_name} =
      params

    with {:ok, account} <- Accounts.Account.create(%{name: account_name}, authorize?: false),
         {:ok, user} <- Accounts.User.create(email, name, password, authorize?: false),
         {:ok, _membership} <-
           Accounts.AccountMembership.create(account.id, user.id, %{role: :owner},
             authorize?: false
           ) do
      {:ok, user}
    else
      {:error, error} -> {:error, error}
    end
  end
end
