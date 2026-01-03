defmodule GroceryPlannerWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use GroceryPlannerWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_user, :any, default: nil
  attr :current_account, :any, default: nil
  attr :voting_active, :boolean, default: false

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div
      id="app-layout"
      phx-hook="ThemeChange"
      data-theme={@current_user && @current_user.theme}
      class="min-h-screen bg-base-200"
    >
      <header class="bg-base-100/50 backdrop-blur-sm px-4 sm:px-6 lg:px-8 border-b border-base-content/10 sticky top-0 z-50">
        <div class="max-w-7xl mx-auto">
          <div class="flex items-center justify-between py-4">
            <div class="flex-1">
              <.link navigate="/dashboard" class="flex items-center gap-2">
                <img src={~p"/images/logo.svg"} width="36" alt="GroceryPlanner logo" />
                <span class="text-xl font-bold text-base-content">GroceryPlanner</span>
              </.link>
            </div>
            
    <!-- Desktop Navigation -->
            <nav class="hidden lg:flex flex-none">
              <ul class="flex items-center space-x-2">
                <%= if assigns[:current_user] do %>
                  <li>
                    <.link
                      navigate="/dashboard"
                      class="px-4 py-2 text-base-content/70 hover:text-base-content font-medium transition"
                    >
                      Dashboard
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate="/inventory"
                      class="px-4 py-2 text-base-content/70 hover:text-base-content font-medium transition"
                    >
                      Inventory
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate="/recipes"
                      class="px-4 py-2 text-base-content/70 hover:text-base-content font-medium transition"
                    >
                      Recipes
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate="/meal-planner"
                      class="px-4 py-2 text-base-content/70 hover:text-base-content font-medium transition"
                    >
                      Meal Planner
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate="/voting"
                      class="px-4 py-2 text-base-content/70 hover:text-base-content font-medium transition flex items-center gap-1"
                    >
                      Voting
                      <span
                        :if={@voting_active}
                        class="relative flex h-2 w-2"
                        title="Voting in progress"
                      >
                        <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-accent opacity-75">
                        </span>
                        <span class="relative inline-flex rounded-full h-2 w-2 bg-accent"></span>
                      </span>
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate="/shopping"
                      class="px-4 py-2 text-base-content/70 hover:text-base-content font-medium transition"
                    >
                      Shopping
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate="/analytics"
                      class="px-4 py-2 text-base-content/70 hover:text-base-content font-medium transition"
                    >
                      Analytics
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate="/settings"
                      class="px-4 py-2 text-base-content/70 hover:text-base-content font-medium transition"
                    >
                      Settings
                    </.link>
                  </li>
                  <li>
                    <.link
                      href="/auth/sign-out"
                      method="delete"
                      class="px-4 py-2 bg-base-200 text-base-content/70 rounded-lg hover:bg-base-300 transition font-medium"
                      data-confirm="Are you sure you want to sign out?"
                    >
                      Sign Out
                    </.link>
                  </li>
                <% else %>
                  <li>
                    <.link
                      navigate="/sign-in"
                      class="px-4 py-2 text-base-content/70 hover:text-base-content font-medium transition"
                    >
                      Sign In
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate="/sign-up"
                      class="btn btn-primary px-6"
                    >
                      Sign Up
                    </.link>
                  </li>
                <% end %>
              </ul>
            </nav>
            
    <!-- Mobile Menu Button -->
            <button
              class="lg:hidden p-2 text-base-content/70 hover:text-base-content hover:bg-base-200 rounded-lg transition"
              phx-click={
                JS.toggle(to: "#mobile-menu") |> JS.toggle_class("hidden", to: "#mobile-menu")
              }
              aria-label="Toggle menu"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M4 6h16M4 12h16M4 18h16"
                />
              </svg>
            </button>
          </div>
          
    <!-- Mobile Navigation Menu -->
          <div id="mobile-menu" class="hidden lg:hidden pb-4">
            <nav class="flex flex-col space-y-2">
              <%= if assigns[:current_user] do %>
                <.link
                  navigate="/dashboard"
                  class="px-4 py-2 text-base-content/70 hover:text-base-content hover:bg-base-200 rounded-lg font-medium transition"
                  phx-click={JS.add_class("hidden", to: "#mobile-menu")}
                >
                  Dashboard
                </.link>
                <.link
                  navigate="/inventory"
                  class="px-4 py-2 text-base-content/70 hover:text-base-content hover:bg-base-200 rounded-lg font-medium transition"
                  phx-click={JS.add_class("hidden", to: "#mobile-menu")}
                >
                  Inventory
                </.link>
                <.link
                  navigate="/recipes"
                  class="px-4 py-2 text-base-content/70 hover:text-base-content hover:bg-base-200 rounded-lg font-medium transition"
                  phx-click={JS.add_class("hidden", to: "#mobile-menu")}
                >
                  Recipes
                </.link>
                <.link
                  navigate="/meal-planner"
                  class="px-4 py-2 text-base-content/70 hover:text-base-content hover:bg-base-200 rounded-lg font-medium transition"
                  phx-click={JS.add_class("hidden", to: "#mobile-menu")}
                >
                  Meal Planner
                </.link>
                <.link
                  navigate="/voting"
                  class="px-4 py-2 text-base-content/70 hover:text-base-content hover:bg-base-200 rounded-lg font-medium transition flex items-center gap-2"
                  phx-click={JS.add_class("hidden", to: "#mobile-menu")}
                >
                  Voting
                  <span
                    :if={@voting_active}
                    class="relative flex h-2 w-2"
                    title="Voting in progress"
                  >
                    <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-accent opacity-75">
                    </span>
                    <span class="relative inline-flex rounded-full h-2 w-2 bg-accent"></span>
                  </span>
                </.link>
                <.link
                  navigate="/shopping"
                  class="px-4 py-2 text-base-content/70 hover:text-base-content hover:bg-base-200 rounded-lg font-medium transition"
                  phx-click={JS.add_class("hidden", to: "#mobile-menu")}
                >
                  Shopping
                </.link>
                <.link
                  navigate="/analytics"
                  class="px-4 py-2 text-base-content/70 hover:text-base-content hover:bg-base-200 rounded-lg font-medium transition"
                  phx-click={JS.add_class("hidden", to: "#mobile-menu")}
                >
                  Analytics
                </.link>
                <.link
                  navigate="/settings"
                  class="px-4 py-2 text-base-content/70 hover:text-base-content hover:bg-base-200 rounded-lg font-medium transition"
                  phx-click={JS.add_class("hidden", to: "#mobile-menu")}
                >
                  Settings
                </.link>
                <.link
                  href="/auth/sign-out"
                  method="delete"
                  class="px-4 py-2 bg-base-200 text-base-content/70 rounded-lg hover:bg-base-300 transition font-medium"
                  data-confirm="Are you sure you want to sign out?"
                >
                  Sign Out
                </.link>
              <% else %>
                <.link
                  navigate="/sign-in"
                  class="px-4 py-2 text-base-content/70 hover:text-base-content hover:bg-base-200 rounded-lg font-medium transition"
                  phx-click={JS.add_class("hidden", to: "#mobile-menu")}
                >
                  Sign In
                </.link>
                <.link
                  navigate="/sign-up"
                  class="btn btn-primary w-full text-center"
                  phx-click={JS.add_class("hidden", to: "#mobile-menu")}
                >
                  Sign Up
                </.link>
              <% end %>
            </nav>
          </div>
        </div>
      </header>

      <main class="max-w-7xl mx-auto">
        {render_slot(@inner_block)}
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
