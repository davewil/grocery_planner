defmodule GroceryPlannerWeb.MealPlannerLive.FocusLayout do
  use GroceryPlannerWeb, :html

  alias GroceryPlannerWeb.MealPlannerLive.Terminology
  import GroceryPlannerWeb.CoreComponents

  def init(socket) do
    # Ensure selected_day is set, default to today if nil
    selected_day = socket.assigns[:selected_day] || Date.utc_today()
    assign(socket, :selected_day, selected_day)
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6" id="focus-mode">
      <div class="sticky top-0 z-30 -mx-4 px-4 pt-3 pb-3 sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8 bg-base-100/95 backdrop-blur border-b border-base-200">
        <div class="flex flex-col gap-3">
          <div class="flex items-center justify-between gap-3">
            <div class="min-w-0">
              <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                Planning
              </div>
              <div class="text-lg font-bold text-base-content truncate" id="focus-current-day">
                {Calendar.strftime(@selected_day, "%A, %B %d")}
              </div>
            </div>

            <div class="flex items-center gap-1">
              <button
                phx-click="focus_prev_day"
                class="p-2 rounded-lg hover:bg-base-200 transition-colors"
                title="Previous day"
                id="focus-prev-day"
              >
                <.icon name="hero-chevron-left" class="w-5 h-5 text-base-content/60" />
              </button>
              <button
                phx-click="focus_today"
                class="btn btn-primary btn-sm"
                id="focus-today"
              >
                Today
              </button>
              <button
                phx-click="focus_next_day"
                class="p-2 rounded-lg hover:bg-base-200 transition-colors"
                title="Next day"
                id="focus-next-day"
              >
                <.icon name="hero-chevron-right" class="w-5 h-5 text-base-content/60" />
              </button>
            </div>
          </div>

          <div class="overflow-x-auto" id="focus-week-strip">
            <div class="flex gap-2 min-w-max">
              <%= for day <- @days do %>
                <% selected = @selected_day == day %>
                <% meal_count =
                  Enum.count(@meal_plans, fn mp ->
                    mp.scheduled_date == day
                  end) %>

                <button
                  phx-click="focus_select_day"
                  phx-value-date={day}
                  class={[
                    "px-3 py-2 rounded-xl border text-left transition-all",
                    selected && "border-primary bg-primary/5",
                    !selected &&
                      "border-base-200 bg-base-100 hover:border-primary/40 hover:bg-primary/5"
                  ]}
                  id={"focus-day-#{day}"}
                >
                  <div class="flex items-center justify-between gap-2">
                    <div>
                      <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                        {Calendar.strftime(day, "%a")}
                      </div>
                      <div class="text-sm font-bold text-base-content">
                        {Calendar.strftime(day, "%d")}
                      </div>
                    </div>
                    <div class={[
                      "min-w-8 h-8 rounded-xl flex items-center justify-center text-xs font-bold",
                      meal_count == 0 && "bg-base-200 text-base-content/50",
                      meal_count > 0 && "bg-primary/10 text-primary"
                    ]}>
                      {meal_count}
                    </div>
                  </div>
                </button>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <div class="grid gap-4" id="focus-slots">
        <%= for meal_type <- [:breakfast, :lunch, :dinner, :snack] do %>
          <%= case get_meal_plan(@selected_day, meal_type, @week_meals) do %>
            <% nil -> %>
              <div class="rounded-2xl border border-base-200 bg-base-100 p-5 shadow-sm">
                <div class="flex items-center justify-between gap-4">
                  <div class="flex items-center gap-3">
                    <div class="w-10 h-10 rounded-2xl bg-base-200 flex items-center justify-center text-lg">
                      <span class="text-base">
                        {Terminology.meal_type_icon(meal_type) |> Terminology.icon_to_emoji()}
                      </span>
                    </div>
                    <div>
                      <div class="text-sm font-bold text-base-content capitalize">
                        {meal_type}
                      </div>
                      <div class="text-sm text-base-content/60">
                        Nothing planned yet
                      </div>
                    </div>
                  </div>

                  <button
                    phx-click="add_meal"
                    phx-value-date={@selected_day}
                    phx-value-meal_type={meal_type}
                    class="btn btn-primary btn-sm"
                    id={"focus-add-#{@selected_day}-#{meal_type}"}
                  >
                    <.icon name="hero-plus" class="w-4 h-4" /> Add
                  </button>
                </div>
              </div>
            <% meal_plan -> %>
              <div
                class="rounded-2xl border border-base-200 bg-base-100 p-5 shadow-sm hover:shadow-md transition-shadow"
                id={"focus-meal-#{meal_plan.id}"}
              >
                <div class="flex items-start justify-between gap-4">
                  <div class="flex items-start gap-3 min-w-0">
                    <div class="w-10 h-10 rounded-2xl bg-primary/10 text-primary flex items-center justify-center text-lg shrink-0">
                      <span class="text-base">
                        {Terminology.meal_type_icon(meal_type) |> Terminology.icon_to_emoji()}
                      </span>
                    </div>
                    <div class="min-w-0">
                      <div class="text-sm font-bold text-base-content capitalize">
                        {meal_type}
                      </div>
                      <div class="mt-1 font-semibold text-base-content truncate">
                        {meal_plan.recipe.name}
                      </div>
                      <div class="mt-1 text-sm text-base-content/60">
                        {meal_plan.servings} servings
                      </div>
                    </div>
                  </div>

                  <div class="flex items-center gap-2 shrink-0">
                    <button
                      phx-click="edit_meal"
                      phx-value-id={meal_plan.id}
                      class="btn btn-ghost btn-sm"
                      id={"focus-edit-#{meal_plan.id}"}
                    >
                      <.icon name="hero-pencil-square" class="w-4 h-4" />
                      <span class="hidden sm:inline">Edit</span>
                    </button>
                    <button
                      phx-click="remove_meal"
                      phx-value-id={meal_plan.id}
                      data-confirm="Are you sure you want to remove this meal?"
                      class="btn btn-ghost btn-sm text-error"
                      id={"focus-remove-#{meal_plan.id}"}
                    >
                      <.icon name="hero-trash" class="w-4 h-4" />
                      <span class="hidden sm:inline">Remove</span>
                    </button>
                  </div>
                </div>
              </div>
          <% end %>
        <% end %>
      </div>

      <button
        phx-click="add_meal"
        phx-value-date={@selected_day}
        phx-value-meal_type="dinner"
        class="fixed bottom-6 right-6 btn btn-primary rounded-full shadow-lg hover:shadow-xl transition-shadow"
        id="focus-fab-add"
        title="Add meal"
      >
        <.icon name="hero-plus" class="w-5 h-5" />
        <span class="hidden sm:inline">Add meal</span>
      </button>
    </div>
    """
  end

  def handle_event("focus_prev_day", _params, socket) do
    date = (socket.assigns.selected_day || Date.utc_today()) |> Date.add(-1)
    {:noreply, assign(socket, :selected_day, date)}
  end

  def handle_event("focus_next_day", _params, socket) do
    date = (socket.assigns.selected_day || Date.utc_today()) |> Date.add(1)
    {:noreply, assign(socket, :selected_day, date)}
  end

  def handle_event("focus_today", _params, socket) do
    {:noreply, assign(socket, :selected_day, Date.utc_today())}
  end

  def handle_event("focus_select_day", %{"date" => date_str}, socket) do
    date = Date.from_iso8601!(date_str)
    {:noreply, assign(socket, :selected_day, date)}
  end

  # Helper for safe map access
  defp get_meal_plan(date, meal_type, week_meals) do
    week_meals
    |> Map.get(date, %{})
    |> Map.get(meal_type)
  end
end
