defmodule GroceryPlannerWeb.InventoryLive.LocationsTab do
  use GroceryPlannerWeb, :html

  attr(:storage_locations, :list, required: true)
  attr(:show_form, :atom, default: nil)
  attr(:form, :any, default: nil)

  def locations_tab(assigns) do
    ~H"""
    <div class="flex justify-end mb-6">
      <.button
        phx-click="new_location"
        class="btn-accent"
      >
        <svg
          class="w-5 h-5 inline mr-2"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 6v6m0 0v6m0-6h6m-6 0H6"
          />
        </svg>
        New Location
      </.button>
    </div>

    <%= if @show_form == :location do %>
      <div class="mb-6 bg-accent/5 border border-accent/20 rounded-xl p-6">
        <h3 class="text-lg font-semibold text-base-content mb-4">Add New Storage Location</h3>
        <.form for={@form} id="location-form" phx-submit="save_location">
          <div class="space-y-4">
            <.input field={@form[:name]} type="text" label="Name" required />
            <.input
              field={@form[:temperature_zone]}
              type="select"
              label="Temperature Zone"
              options={[
                {"Frozen", "frozen"},
                {"Cold (Refrigerated)", "cold"},
                {"Cool", "cool"},
                {"Room Temperature", "room_temp"}
              ]}
            />

            <div class="flex gap-2 justify-end">
              <.button
                type="button"
                phx-click="cancel_form"
                class="btn-ghost"
              >
                Cancel
              </.button>
              <.button
                type="submit"
                class="btn-accent"
              >
                Save Location
              </.button>
            </div>
          </div>
        </.form>
      </div>
    <% end %>

    <div class="space-y-3">
      <div
        :for={location <- @storage_locations}
        class="flex items-center justify-between p-5 bg-base-200/30 rounded-xl border border-base-200 hover:border-accent/30 hover:bg-accent/5 transition"
      >
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-accent/10 rounded-lg flex items-center justify-center flex-shrink-0">
            <svg
              class="w-6 h-6 text-accent"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
              />
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
              />
            </svg>
          </div>
          <div>
            <div class="font-semibold text-base-content">{location.name}</div>
            <div
              :if={location.temperature_zone}
              class="text-sm text-accent mt-1 capitalize"
            >
              Temperature: {location.temperature_zone}
            </div>
          </div>
        </div>
        <.button
          phx-click="delete_location"
          phx-value-id={location.id}
          class="btn-error btn-outline btn-sm"
        >
          Delete
        </.button>
      </div>

      <div :if={@storage_locations == []} class="text-center py-16">
        <svg
          class="w-16 h-16 text-base-content/20 mx-auto mb-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
          />
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
          />
        </svg>
        <p class="text-base-content/50 font-medium">No storage locations yet</p>
      </div>
    </div>
    """
  end
end
