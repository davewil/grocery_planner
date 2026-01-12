defmodule GroceryPlannerWeb.MealPlannerLive.PowerLayout do
  use GroceryPlannerWeb, :html

  alias GroceryPlannerWeb.MealPlannerLive.Terminology
  import GroceryPlannerWeb.CoreComponents

  def init(socket) do
    socket
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6" id="power-mode">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div>
          <h2 class="text-lg font-bold text-base-content">Week board</h2>
          <p class="text-sm text-base-content/60">
            Add, edit, and move fast across the week.
          </p>
        </div>

        <div class="flex items-center gap-2">
          <button phx-click="prev_week" class="btn btn-ghost btn-sm" id="power-prev-week">
            <.icon name="hero-chevron-left" class="w-4 h-4" /> Prev
          </button>
          <button phx-click="today" class="btn btn-primary btn-sm" id="power-today">
            This week
          </button>
          <button phx-click="next_week" class="btn btn-ghost btn-sm" id="power-next-week">
            Next <.icon name="hero-chevron-right" class="w-4 h-4" />
          </button>
        </div>
      </div>

      <div class="overflow-x-auto" id="power-week-board">
        <div
          class="grid gap-4 min-w-[980px]"
          style="grid-template-columns: repeat(7, minmax(0, 1fr));"
        >
          <%= for day <- @days do %>
            <% meal_count =
              Enum.count(@meal_plans, fn mp ->
                mp.scheduled_date == day
              end) %>

            <div class="rounded-2xl border border-base-200 bg-base-100 shadow-sm overflow-hidden">
              <div class={[
                "px-4 py-3 flex items-start justify-between gap-2 border-b",
                if(Date.compare(day, Date.utc_today()) == :eq,
                  do: "bg-primary text-primary-content border-transparent",
                  else: "bg-base-200 text-base-content border-base-200"
                )
              ]}>
                <div class="min-w-0">
                  <div class="text-sm font-bold truncate">
                    {Calendar.strftime(day, "%a")}
                  </div>
                  <div class={[
                    "text-xs",
                    Date.compare(day, Date.utc_today()) == :eq && "opacity-80",
                    Date.compare(day, Date.utc_today()) != :eq && "text-base-content/60"
                  ]}>
                    {Calendar.strftime(day, "%b %d")}
                  </div>
                </div>
                <div class={[
                  "w-8 h-8 rounded-xl flex items-center justify-center text-xs font-bold",
                  meal_count == 0 && "bg-base-100/60 text-base-content/50",
                  meal_count > 0 && "bg-primary-content/20 text-primary-content"
                ]}>
                  {meal_count}
                </div>
              </div>

              <div class="p-3 space-y-2">
                <%= for meal_type <- [:breakfast, :lunch, :dinner, :snack] do %>
                  <%= case get_meal_plan(day, meal_type, @week_meals) do %>
                    <% nil -> %>
                      <button
                        phx-click="add_meal"
                        phx-value-date={day}
                        phx-value-meal_type={meal_type}
                        class="w-full rounded-xl border border-dashed border-base-300 bg-base-100 px-3 py-3 text-left hover:border-primary/40 hover:bg-primary/5 transition"
                        id={"power-add-#{day}-#{meal_type}"}
                      >
                        <div class="flex items-center justify-between gap-2">
                          <div class="text-xs font-bold uppercase tracking-wide text-base-content/60 flex items-center gap-2">
                            <span class="text-base">
                              {Terminology.meal_type_icon(meal_type) |> Terminology.icon_to_emoji()}
                            </span>
                            <span class="capitalize">{meal_type}</span>
                          </div>
                          <.icon name="hero-plus" class="w-4 h-4 text-base-content/30" />
                        </div>
                        <div class="mt-1 text-sm text-base-content/50">Add</div>
                      </button>
                    <% meal_plan -> %>
                      <div
                        class="w-full rounded-xl border border-base-200 bg-base-100 px-3 py-3 hover:border-primary/30 hover:shadow-sm transition"
                        id={"power-meal-#{meal_plan.id}"}
                      >
                        <div class="flex items-start justify-between gap-2">
                          <div class="min-w-0">
                            <div class="text-xs font-bold uppercase tracking-wide text-base-content/60 flex items-center gap-2">
                              <span class="text-base">
                                {Terminology.meal_type_icon(meal_type) |> Terminology.icon_to_emoji()}
                              </span>
                              <span class="capitalize">{meal_type}</span>
                            </div>
                            <div class="mt-1 text-sm font-semibold text-base-content truncate">
                              {meal_plan.recipe.name}
                            </div>
                            <div class="mt-1 text-xs text-base-content/50">
                              {meal_plan.servings} servings
                            </div>
                          </div>

                          <div class="flex items-center gap-1 shrink-0">
                            <button
                              phx-click="edit_meal"
                              phx-value-id={meal_plan.id}
                              class="p-2 rounded-lg hover:bg-base-200 transition-colors"
                              title="Edit"
                            >
                              <.icon
                                name="hero-pencil-square"
                                class="w-4 h-4 text-base-content/50"
                              />
                            </button>
                            <button
                              phx-click="remove_meal"
                              phx-value-id={meal_plan.id}
                              data-confirm="Are you sure you want to remove this meal?"
                              class="p-2 rounded-lg hover:bg-error/10 text-error transition-colors"
                              title="Remove"
                            >
                              <.icon name="hero-trash" class="w-4 h-4" />
                            </button>
                          </div>
                        </div>

                        <div class="mt-3 grid grid-cols-2 gap-2">
                          <button
                            phx-click="move_meal"
                            phx-value-id={meal_plan.id}
                            phx-value-direction="prev"
                            class="btn btn-ghost btn-xs"
                            title="Move to previous day"
                          >
                            <.icon name="hero-arrow-left" class="w-3 h-3" /> Prev
                          </button>
                          <button
                            phx-click="move_meal"
                            phx-value-id={meal_plan.id}
                            phx-value-direction="next"
                            class="btn btn-ghost btn-xs"
                            title="Move to next day"
                          >
                            Next <.icon name="hero-arrow-right" class="w-3 h-3" />
                          </button>
                        </div>
                      </div>
                  <% end %>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
      
    <!-- Undo button usually in layout, handled by Main LiveView via UndoSystem -->
    </div>
    """
  end

  # Helper for safe map access
  defp get_meal_plan(date, meal_type, week_meals) do
    week_meals
    |> Map.get(date, %{})
    |> Map.get(meal_type)
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # Helper for icon mapping
end
