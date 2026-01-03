defmodule GroceryPlannerWeb.DashboardLive do
  use GroceryPlannerWeb, :live_view
  import GroceryPlannerWeb.UIComponents

  on_mount {GroceryPlannerWeb.Auth, :require_authenticated_user}

  alias GroceryPlanner.MealPlanning.Voting
  alias GroceryPlanner.Notifications.ExpirationAlerts
  alias GroceryPlanner.Notifications.RecipeSuggestions

  def mount(_params, _session, socket) do
    account_id = socket.assigns.current_account.id
    user = socket.assigns.current_user
    voting_active = Voting.voting_active?(account_id, user)

    # Load expiration alerts
    {:ok, expiring_summary} =
      ExpirationAlerts.get_expiring_summary(account_id, user, days_threshold: 7)

    {:ok, expiring_items} =
      ExpirationAlerts.get_expiring_items(account_id, user, days_threshold: 7)

    # Load recipe suggestions based on expiring items
    {:ok, recipe_suggestions} =
      RecipeSuggestions.get_suggestions_for_expiring_items(account_id, user,
        days_threshold: 7,
        limit: 5
      )

    socket =
      socket
      |> assign(:current_scope, socket.assigns.current_account)
      |> assign(:voting_active, voting_active)
      |> assign(:expiring_summary, expiring_summary)
      |> assign(:expiring_items, expiring_items)
      |> assign(:recipe_suggestions, recipe_suggestions)

    {:ok, socket}
  end
end
