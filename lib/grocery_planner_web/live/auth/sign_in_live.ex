defmodule GroceryPlannerWeb.Auth.SignInLive do
  use GroceryPlannerWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-sm mt-20">
        <.header>
          Sign In
          <:subtitle>
            Don't have an account?
            <.link navigate="/sign-up" class="font-semibold text-brand hover:underline">
              Sign up
            </.link>
          </:subtitle>
        </.header>

        <.form for={@form} id="sign-in-form" action="/auth/sign-in" method="post" class="mt-10">
        <div class="space-y-4">
          <div>
            <label for="user_email" class="block text-sm font-medium">Email</label>
            <input
              type="email"
              name="user[email]"
              id="user_email"
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-zinc-400 focus:ring focus:ring-zinc-200 focus:ring-opacity-50"
            />
          </div>

          <div>
            <label for="user_password" class="block text-sm font-medium">Password</label>
            <input
              type="password"
              name="user[password]"
              id="user_password"
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-zinc-400 focus:ring focus:ring-zinc-200 focus:ring-opacity-50"
            />
          </div>

          <div>
            <.button class="w-full">Sign In</.button>
          </div>
        </div>
      </.form>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    form = to_form(%{}, as: :user)
    {:ok, assign(socket, form: form)}
  end
end
