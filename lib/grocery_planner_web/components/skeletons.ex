defmodule GroceryPlannerWeb.Components.Skeletons do
  use Phoenix.Component

  def recipe_card_skeleton(assigns) do
    ~H"""
    <div class="card bg-base-100 animate-pulse border border-base-200">
      <div class="aspect-[4/3] bg-base-200 w-full"></div>
      <div class="p-4">
        <div class="h-5 bg-base-200 rounded w-3/4 mb-2"></div>
        <div class="h-4 bg-base-200 rounded w-1/2"></div>
        <div class="flex gap-2 mt-4">
          <div class="h-8 bg-base-200 rounded w-full"></div>
          <div class="h-8 bg-base-200 rounded w-8"></div>
        </div>
      </div>
    </div>
    """
  end

  def meal_slot_skeleton(assigns) do
    ~H"""
    <div class="bg-base-100 rounded-xl border border-base-200 p-4 animate-pulse">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 bg-base-200 rounded-lg"></div>
        <div class="flex-1">
          <div class="h-4 bg-base-200 rounded w-1/2 mb-2"></div>
          <div class="h-3 bg-base-200 rounded w-1/3"></div>
        </div>
      </div>
    </div>
    """
  end

  def day_column_skeleton(assigns) do
    ~H"""
    <div class="flex-1 min-w-[120px] border-r border-base-200 animate-pulse">
      <div class="p-3 text-center border-b border-base-200 bg-base-100">
        <div class="h-3 bg-base-200 rounded w-8 mx-auto mb-1"></div>
        <div class="h-5 bg-base-200 rounded w-6 mx-auto"></div>
      </div>
      <div class="p-2 space-y-3">
        <%= for _ <- 1..4 do %>
          <div class="h-20 bg-base-200 rounded-xl"></div>
        <% end %>
      </div>
    </div>
    """
  end
end
