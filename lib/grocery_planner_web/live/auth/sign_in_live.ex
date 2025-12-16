defmodule GroceryPlannerWeb.Auth.SignInLive do
  use GroceryPlannerWeb, :live_view

  def mount(_params, _session, socket) do
    form = to_form(%{}, as: :user)
    {:ok, assign(socket, form: form)}
  end
end
