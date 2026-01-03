defmodule GroceryPlannerWeb.UIComponents do
  @moduledoc """
  Reusable UI components for GroceryPlanner.

  This module provides standardized, theme-aware components that are used
  across the application for consistent UX and easier maintenance.

  ## Components

  - `empty_state/1` - Empty state placeholder
  - `stat_card/1` - KPI/statistic display card

  Note: For modal dialogs, use the `modal/1` component from `CoreComponents`

  ## Usage

      import GroceryPlannerWeb.UIComponents

      <.empty_state icon="hero-cube" title="No items yet" />
      <.stat_card icon="hero-cube" color="primary" label="Total" value="42" />
  """
  use Phoenix.Component
  import GroceryPlannerWeb.CoreComponents

  @doc """
  Renders an empty state placeholder.

  Displays when a list or collection has no items, with optional action button.

  ## Attributes

  - `icon` - Required. Heroicon name (e.g., "hero-cube")
  - `title` - Required. Main message
  - `description` - Optional. Secondary message
  - `padding` - Optional. Padding class (default: "py-16")

  ## Slots

  - `action` - Optional slot for action button

  ## Examples

      <.empty_state
        icon="hero-book-open"
        title="No recipes yet"
        description="Click 'New Recipe' to add your first recipe"
      />

      <.empty_state icon="hero-shopping-cart" title="No shopping lists">
        <:action>
          <.button phx-click="new_list" class="btn-primary mt-4">
            Create List
          </.button>
        </:action>
      </.empty_state>
  """
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :padding, :string, default: "py-16"

  slot :action

  def empty_state(assigns) do
    ~H"""
    <div class={"text-center #{@padding}"}>
      <.icon name={@icon} class="w-16 h-16 text-base-content/20 mx-auto mb-4" />
      <p class="text-base-content/50 font-medium">{@title}</p>
      <p :if={@description} class="text-base-content/30 text-sm mt-1">{@description}</p>
      <div :if={@action != []}>
        {render_slot(@action)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a KPI/statistic card.

  Displays a key metric with icon, label, value, and optional description.
  Can be clickable (link) or static (div).

  ## Attributes

  - `icon` - Required. Heroicon name
  - `color` - Required. Semantic color (primary, success, warning, error, info, accent, secondary)
  - `label` - Required. Metric label
  - `value` - Required. Main value to display
  - `description` - Optional. Additional context
  - `link` - Optional. If provided, card becomes clickable link
  - `value_suffix` - Optional. Suffix for value (e.g., "items", "%")

  ## Examples

      <.stat_card
        icon="hero-cube"
        color="primary"
        label="Total Inventory"
        value="127"
        value_suffix="items"
        description="15 individual units"
      />

      <.stat_card
        icon="hero-fire"
        color="error"
        label="Expired"
        value="3"
        description="Remove immediately"
        link={~p"/inventory?expiring=expired"}
      />
  """
  attr :icon, :string, required: true
  attr :color, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :description, :string, default: nil
  attr :link, :string, default: nil
  attr :value_suffix, :string, default: nil

  def stat_card(%{link: nil} = assigns) do
    ~H"""
    <div class="bg-base-100 p-6 rounded-2xl shadow-sm border border-base-200">
      <div class="flex items-center gap-4">
        <div class={"w-12 h-12 bg-#{@color}/10 rounded-xl flex items-center justify-center text-#{@color}"}>
          <.icon name={@icon} class="w-6 h-6" />
        </div>
        <div>
          <p class="text-sm font-medium text-base-content/60">{@label}</p>
          <div class="flex items-baseline gap-2">
            <h3 class={"text-2xl font-bold text-#{stat_value_color(@color)}"}>{@value}</h3>
            <span :if={@value_suffix} class="text-sm text-base-content/60">{@value_suffix}</span>
          </div>
          <p :if={@description} class={"text-xs mt-1 #{stat_description_color(@color)}"}>
            {@description}
          </p>
        </div>
      </div>
    </div>
    """
  end

  def stat_card(assigns) do
    ~H"""
    <.link
      navigate={@link}
      class={"p-6 rounded-2xl border-2 hover:shadow-lg transition-all cursor-pointer bg-#{@color}/10 border-#{@color} hover:border-#{@color}"}
    >
      <h3 class={"text-sm font-medium mb-1 text-#{@color}"}>{@label}</h3>
      <div class="flex items-baseline gap-2">
        <p class={"text-3xl font-bold text-#{@color}"}>{@value}</p>
        <span :if={@value_suffix} class={"text-sm text-#{@color}/80"}>{@value_suffix}</span>
      </div>
      <p :if={@description} class={"text-sm mt-1 text-#{@color}/80"}>{@description}</p>
    </.link>
    """
  end

  # Helper to determine text color for stat card values
  defp stat_value_color("error"), do: "text-error"
  defp stat_value_color("warning"), do: "text-warning"
  defp stat_value_color("success"), do: "text-success"
  defp stat_value_color("info"), do: "text-info"
  defp stat_value_color("primary"), do: "text-base-content"
  defp stat_value_color("secondary"), do: "text-base-content"
  defp stat_value_color("accent"), do: "text-base-content"
  defp stat_value_color(_), do: "text-base-content"

  # Helper to determine description color for stat card
  defp stat_description_color("error"), do: "text-error"
  defp stat_description_color("warning"), do: "text-warning/80"
  defp stat_description_color("info"), do: "text-info/80"
  defp stat_description_color(_), do: "text-base-content/50"
end
