defmodule GroceryPlannerWeb.AITestLive do
  use GroceryPlannerWeb, :live_view
  alias GroceryPlanner.AI.Categorizer
  require Logger

  def render(assigns) do
    ~H"""
    <div class="p-4">
      <h1 class="text-2xl mb-4">AI Categorization Spike</h1>

      <%= if @loading do %>
        <div class="mb-4 p-4 bg-blue-100 text-blue-800 rounded">
          <p class="font-bold">Loading Model...</p>
          <p class="text-sm mt-1">This involves downloading ~330MB of model weights from Hugging Face.</p>
          <p class="text-sm">Please be patient. Check your terminal logs for download progress.</p>
        </div>
      <% end %>

      <%= if @error do %>
        <div class="mb-4 p-4 bg-red-100 text-red-800 rounded">
          <p class="font-bold">Error:</p>
          <pre>{@error}</pre>
        </div>
      <% end %>

      <%= if @model_ready do %>
        <div class="mb-4 p-4 bg-green-100 text-green-800 rounded">Model is Ready!</div>
        <.form for={@form} phx-submit="predict" class="flex gap-2 mb-4">
          <.input field={@form[:text]} placeholder="Item name (e.g. Milk)" />
          <.button>Predict Category</.button>
        </.form>
      <% else %>
        <button phx-click="load_model" class="bg-blue-500 text-white px-4 py-2 rounded disabled:opacity-50" disabled={@loading}>
          {if @loading, do: "Loading...", else: "Load Model (Download ~330MB)"}
        </button>
      <% end %>

      <%= if @prediction do %>
        <div class="mt-4 border p-4 rounded bg-gray-50">
          <h2 class="font-bold mb-2">Prediction:</h2>
          <pre>{inspect(@prediction, pretty: true)}</pre>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    ready = Process.whereis(Categorizer) != nil
    {:ok, assign(socket, model_ready: ready, loading: false, error: nil, prediction: nil, form: to_form(%{"text" => ""}))}
  end

  def handle_event("load_model", _, socket) do
    Logger.info("Starting model load task...")
    pid = self()
    Task.start(fn ->
      try do
        Logger.info("Checking if process exists...")
        if Process.whereis(Categorizer) do
           Logger.info("Process exists!")
           send(pid, :model_loaded)
        else
           Logger.info("Loading serving...")
           serving = Categorizer.serving()
           Logger.info("Serving loaded. Starting link...")
           case Nx.Serving.start_link(serving: serving, name: Categorizer) do
             {:ok, serving_pid} ->
               Logger.info("Started link successfully.")
               Process.unlink(serving_pid)
               send(pid, :model_loaded)
             {:error, {:already_started, _}} ->
               Logger.info("Already started.")
               send(pid, :model_loaded)
             {:error, reason} ->
               Logger.error("Error starting link: #{inspect(reason)}")
               send(pid, {:model_error, reason})
           end
        end
      rescue
        e ->
            Logger.error("Exception in task: #{inspect(e)}")
            send(pid, {:model_error, e})
      end
    end)

    {:noreply, assign(socket, loading: true, error: nil)}
  end

  def handle_event("predict", %{"text" => text}, socket) do
    Logger.info("Predicting category for: #{text}")
    
    # Run prediction in a Task to avoid blocking the LV and to handle timeouts
    target = self()
    
    Task.start(fn -> 
      try do
        # labels are now fixed in the serving for this spike
        result = Categorizer.predict(text, [])
        Logger.info("Prediction result: #{inspect(result)}")
        send(target, {:prediction_result, result})
      catch
        kind, reason -> 
          Logger.error("Prediction failed: #{inspect(reason)}")
          send(target, {:prediction_error, inspect(reason)})
      end
    end)
    
    {:noreply, assign(socket, prediction: "Predicting...", error: nil)}
  end

  def handle_info({:prediction_result, result}, socket) do
    {:noreply, assign(socket, prediction: result)}
  end

  def handle_info({:prediction_error, reason}, socket) do
    {:noreply, assign(socket, prediction: nil, error: "Prediction failed: #{reason}")}
  end

  def handle_info(:model_loaded, socket) do
    {:noreply, assign(socket, loading: false, model_ready: true)}
  end

  def handle_info({:model_error, e}, socket) do
    {:noreply, assign(socket, loading: false, error: inspect(e))}
  end
end
