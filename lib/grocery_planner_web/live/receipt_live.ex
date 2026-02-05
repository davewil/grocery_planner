defmodule GroceryPlannerWeb.ReceiptLive do
  @moduledoc """
  Multi-step LiveView for receipt scanning and OCR processing.

  Steps:
  1. Upload - Drag-drop or file select for receipt images
  2. Processing - Real-time status updates via PubSub
  3. Review - Edit extracted items, view match confidence
  4. Complete - Confirmation and link to inventory
  """
  use GroceryPlannerWeb, :live_view

  on_mount({GroceryPlannerWeb.Auth, :require_authenticated_user})

  alias GroceryPlanner.Inventory
  alias GroceryPlanner.Inventory.{ReceiptProcessor, ItemMatcher}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Scan Receipt")
      |> assign(:step, :upload)
      |> assign(:receipt, nil)
      |> assign(:receipt_items, [])
      |> assign(:processing_status, nil)
      |> assign(:error, nil)
      |> assign(:catalog_search_idx, nil)
      |> assign(:catalog_search_query, "")
      |> assign(:catalog_search_results, [])
      |> allow_upload(:receipt,
        accept: ~w(.jpg .jpeg .png .heic .pdf),
        max_entries: 1,
        max_file_size: 10_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_account={@current_account}
    >
      <div class="px-4 py-10 sm:px-6 lg:px-8">
        <div class="max-w-4xl mx-auto">
          <h1 class="text-3xl font-bold text-base-content mb-6">Scan Receipt</h1>
          
    <!-- Step indicator -->
          <ul class="steps steps-horizontal w-full mb-8">
            <li class={step_class(:upload, @step)}>Upload</li>
            <li class={step_class(:processing, @step)}>Processing</li>
            <li class={step_class(:review, @step)}>Review</li>
            <li class={step_class(:complete, @step)}>Done</li>
          </ul>

          <%= if @error do %>
            <div class="alert alert-error mb-4">
              <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
              <span>{@error}</span>
              <button type="button" class="btn btn-ghost btn-sm" phx-click="clear_error">
                Dismiss
              </button>
            </div>
          <% end %>

          <%= case @step do %>
            <% :upload -> %>
              <.upload_step uploads={@uploads} />
            <% :processing -> %>
              <.processing_step status={@processing_status} />
            <% :review -> %>
              <.review_step
                receipt={@receipt}
                items={@receipt_items}
                catalog_search_idx={@catalog_search_idx}
                catalog_search_query={@catalog_search_query}
                catalog_search_results={@catalog_search_results}
              />
            <% :complete -> %>
              <.complete_step receipt={@receipt} items={@receipt_items} />
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Step components
  # ---------------------------------------------------------------------------

  defp upload_step(assigns) do
    ~H"""
    <form id="upload-form" phx-submit="upload" phx-change="validate_upload">
      <div
        class="border-2 border-dashed border-base-300 rounded-xl p-12 text-center hover:border-primary transition-colors cursor-pointer"
        phx-drop-target={@uploads.receipt.ref}
      >
        <.icon name="hero-camera" class="w-16 h-16 mx-auto text-base-content/50 mb-4" />
        <h3 class="text-lg font-medium mb-2">Upload Receipt</h3>
        <p class="text-base-content/70 mb-4">Drag &amp; drop or click to select</p>
        <.live_file_input upload={@uploads.receipt} class="hidden" />
        <label for={@uploads.receipt.ref} class="btn btn-primary cursor-pointer">
          Choose File
        </label>
      </div>

      <%= for entry <- @uploads.receipt.entries do %>
        <div class="mt-4 flex items-center gap-4">
          <div class="flex-1">
            <p class="font-medium">{entry.client_name}</p>
            <progress class="progress progress-primary w-full" value={entry.progress} max="100">
              {entry.progress}%
            </progress>
          </div>
          <button
            type="button"
            class="btn btn-ghost btn-sm"
            phx-click="cancel_upload"
            phx-value-ref={entry.ref}
          >
            <.icon name="hero-x-mark" class="w-4 h-4" />
          </button>
        </div>

        <%= for err <- upload_errors(@uploads.receipt, entry) do %>
          <p class="text-error text-sm mt-1">{error_to_string(err)}</p>
        <% end %>
      <% end %>

      <div class="mt-6 text-center">
        <button
          type="submit"
          class="btn btn-primary btn-lg"
          disabled={@uploads.receipt.entries == []}
        >
          <.icon name="hero-arrow-up-tray" class="w-5 h-5" /> Upload &amp; Process
        </button>
      </div>

      <p class="text-sm text-base-content/50 text-center mt-4">
        Supports JPEG, PNG, HEIC, PDF up to 10MB
      </p>
    </form>
    """
  end

  defp processing_step(assigns) do
    ~H"""
    <div class="flex flex-col items-center gap-6 py-12">
      <span class="loading loading-spinner loading-lg text-primary"></span>
      <p class="text-lg font-medium">{@status || "Processing receipt..."}</p>
      <ul class="steps steps-vertical">
        <li class="step step-primary">Uploading</li>
        <li class={
          if @status in ["Extracting text...", "Matching items...", "Complete"],
            do: "step step-primary",
            else: "step"
        }>
          Reading text (OCR)
        </li>
        <li class={
          if @status in ["Matching items...", "Complete"],
            do: "step step-primary",
            else: "step"
        }>
          Extracting items
        </li>
        <li class={if @status == "Complete", do: "step step-primary", else: "step"}>
          Matching to catalog
        </li>
      </ul>
    </div>
    """
  end

  defp review_step(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Receipt Summary -->
      <div class="bg-base-200 rounded-xl p-4">
        <div class="flex justify-between items-center">
          <div>
            <p class="font-medium text-lg">{@receipt.merchant_name || "Unknown Store"}</p>
            <p class="text-sm text-base-content/70">
              <%= if @receipt.purchase_date do %>
                {Calendar.strftime(@receipt.purchase_date, "%B %d, %Y")}
              <% else %>
                Date unknown
              <% end %>
            </p>
          </div>
          <div class="text-right">
            <p class="text-sm text-base-content/70">
              {length(@items)} items extracted
            </p>
          </div>
        </div>
      </div>
      
    <!-- Items List -->
      <div class="space-y-2">
        <%= for {item, idx} <- Enum.with_index(@items) do %>
          <div class="bg-base-100 rounded-lg p-4 border border-base-300">
            <div class="flex items-center gap-3">
              <!-- Confidence indicator -->
              <div class={["w-2 h-8 rounded-full flex-shrink-0", confidence_color(item.confidence)]} />
              
    <!-- Item name -->
              <div class="flex-1 min-w-0">
                <input
                  type="text"
                  value={item.final_name || item.raw_name}
                  class="input input-sm input-bordered w-full"
                  phx-blur="update_item_name"
                  phx-value-idx={idx}
                />
              </div>
              
    <!-- Quantity -->
              <div class="w-20">
                <input
                  type="number"
                  step="any"
                  value={format_decimal(item.final_quantity || item.quantity)}
                  class="input input-sm input-bordered w-full"
                  phx-blur="update_item_quantity"
                  phx-value-idx={idx}
                />
              </div>
              
    <!-- Unit -->
              <div class="w-20">
                <input
                  type="text"
                  value={item.final_unit || item.unit || ""}
                  class="input input-sm input-bordered w-full"
                  placeholder="unit"
                  phx-blur="update_item_unit"
                  phx-value-idx={idx}
                />
              </div>
              
    <!-- Delete -->
              <button
                type="button"
                class="btn btn-ghost btn-sm btn-square flex-shrink-0"
                phx-click="remove_item"
                phx-value-idx={idx}
              >
                <.icon name="hero-trash" class="w-4 h-4" />
              </button>
            </div>
            
    <!-- Match status -->
            <div class="mt-2 ml-5 text-sm flex items-center gap-2">
              <%= if item.grocery_item_id do %>
                <span class="badge badge-success badge-sm">
                  Matched ({format_confidence(item.match_confidence)})
                </span>
                <button
                  type="button"
                  class="link link-primary text-xs"
                  phx-click="open_catalog_search"
                  phx-value-idx={idx}
                >
                  Change
                </button>
              <% else %>
                <span class="badge badge-warning badge-sm">No match</span>
                <span class="text-base-content/50">Will create new item</span>
                <button
                  type="button"
                  class="link link-primary text-xs"
                  phx-click="open_catalog_search"
                  phx-value-idx={idx}
                >
                  Find match
                </button>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
      
    <!-- Actions -->
      <div class="flex justify-between items-center pt-4 border-t border-base-300">
        <button type="button" class="btn btn-ghost" phx-click="back_to_upload">
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Start Over
        </button>
        <div class="flex gap-2">
          <button type="button" class="btn btn-outline" phx-click="add_manual_item">
            <.icon name="hero-plus" class="w-4 h-4" /> Add Item
          </button>
          <button type="button" class="btn btn-primary" phx-click="confirm_import">
            <.icon name="hero-check" class="w-4 h-4" /> Add {length(@items)} Items to Inventory
          </button>
        </div>
      </div>

      <%= if assigns[:catalog_search_idx] do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">Match to Catalog Item</h3>
            <form id="catalog-search-form" phx-change="catalog_search" phx-submit="catalog_search">
              <input
                type="text"
                value={@catalog_search_query}
                placeholder="Search grocery items..."
                class="input input-bordered w-full mb-4"
                phx-debounce="200"
                name="query"
              />
            </form>
            <div class="max-h-60 overflow-y-auto space-y-1">
              <%= for gi <- @catalog_search_results do %>
                <button
                  type="button"
                  class="w-full flex items-center gap-3 p-2 rounded-lg hover:bg-base-200 text-left"
                  phx-click="select_catalog_match"
                  phx-value-grocery-item-id={gi.id}
                  phx-value-grocery-item-name={gi.name}
                >
                  <span class="font-medium text-sm">{gi.name}</span>
                  <%= if gi.default_unit do %>
                    <span class="text-xs text-base-content/50">{gi.default_unit}</span>
                  <% end %>
                </button>
              <% end %>
              <%= if @catalog_search_results == [] and @catalog_search_query != "" do %>
                <p class="text-center text-base-content/50 py-4">No items found</p>
              <% end %>
            </div>
            <div class="modal-action">
              <button type="button" class="btn btn-ghost" phx-click="close_catalog_search">
                Cancel
              </button>
              <button type="button" class="btn btn-outline" phx-click="create_and_match">
                Create New Item
              </button>
            </div>
          </div>
          <div class="modal-backdrop" phx-click="close_catalog_search"></div>
        </div>
      <% end %>
    </div>
    """
  end

  defp complete_step(assigns) do
    confirmed_count =
      Enum.count(assigns.items, fn item ->
        item_status(item) == :confirmed
      end)

    assigns = assign(assigns, :confirmed_count, confirmed_count)

    ~H"""
    <div class="flex flex-col items-center gap-6 py-12">
      <div class="w-20 h-20 rounded-full bg-success/20 flex items-center justify-center">
        <.icon name="hero-check" class="w-10 h-10 text-success" />
      </div>
      <h2 class="text-xl font-bold">Receipt Imported</h2>
      <p class="text-base-content/70">
        {@confirmed_count} items added to your inventory
      </p>
      <div class="flex gap-4">
        <button type="button" class="btn btn-outline" phx-click="scan_another">
          Scan Another Receipt
        </button>
        <.link navigate={~p"/inventory"} class="btn btn-primary">
          View Inventory
        </.link>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("upload", _params, socket) do
    account = socket.assigns.current_account
    user = socket.assigns.current_user

    consumed_entries =
      consume_uploaded_entries(socket, :receipt, fn %{path: path}, entry ->
        {:ok, %{path: path, client_name: entry.client_name}}
      end)

    case consumed_entries do
      [file_params | _] ->
        case ReceiptProcessor.upload(file_params, user, account) do
          {:ok, receipt} ->
            # Subscribe to processing updates
            if connected?(socket) do
              Phoenix.PubSub.subscribe(GroceryPlanner.PubSub, "receipt:#{receipt.id}")
            end

            # Trigger immediate processing instead of waiting for AshOban cron scheduler
            AshOban.run_trigger(receipt, :process)

            socket =
              socket
              |> assign(:step, :processing)
              |> assign(:receipt, receipt)
              |> assign(:processing_status, "Processing receipt...")

            {:noreply, socket}

          {:error, :duplicate_receipt} ->
            {:noreply, assign(socket, :error, "This receipt has already been uploaded.")}

          {:error, reason} ->
            {:noreply, assign(socket, :error, "Upload failed: #{inspect(reason)}")}
        end

      [] ->
        {:noreply, assign(socket, :error, "Please select a file to upload.")}
    end
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :receipt, ref)}
  end

  @impl true
  def handle_event("clear_error", _, socket) do
    {:noreply, assign(socket, :error, nil)}
  end

  @impl true
  def handle_event("update_item_name", %{"idx" => idx, "value" => value}, socket) do
    idx = String.to_integer(idx)

    items =
      List.update_at(socket.assigns.receipt_items, idx, fn item ->
        Map.put(item, :final_name, value)
      end)

    {:noreply, assign(socket, :receipt_items, items)}
  end

  @impl true
  def handle_event("update_item_quantity", %{"idx" => idx, "value" => value}, socket) do
    idx = String.to_integer(idx)

    quantity =
      case Decimal.parse(value) do
        {d, _} -> d
        :error -> nil
      end

    items =
      List.update_at(socket.assigns.receipt_items, idx, fn item ->
        Map.put(item, :final_quantity, quantity)
      end)

    {:noreply, assign(socket, :receipt_items, items)}
  end

  @impl true
  def handle_event("update_item_unit", %{"idx" => idx, "value" => value}, socket) do
    idx = String.to_integer(idx)

    items =
      List.update_at(socket.assigns.receipt_items, idx, fn item ->
        Map.put(item, :final_unit, value)
      end)

    {:noreply, assign(socket, :receipt_items, items)}
  end

  @impl true
  def handle_event("remove_item", %{"idx" => idx}, socket) do
    idx = String.to_integer(idx)
    items = List.delete_at(socket.assigns.receipt_items, idx)
    {:noreply, assign(socket, :receipt_items, items)}
  end

  @impl true
  def handle_event("add_manual_item", _, socket) do
    new_item = %{
      id: nil,
      raw_name: "",
      final_name: "",
      quantity: Decimal.new(1),
      unit: nil,
      confidence: 1.0,
      grocery_item_id: nil,
      status: :pending,
      final_quantity: nil,
      final_unit: nil,
      match_confidence: nil
    }

    items = socket.assigns.receipt_items ++ [new_item]
    {:noreply, assign(socket, :receipt_items, items)}
  end

  @impl true
  def handle_event("confirm_import", _, socket) do
    receipt = socket.assigns.receipt
    items = socket.assigns.receipt_items

    # Update all items that have DB IDs as confirmed
    for item <- items, item.id do
      Inventory.update_receipt_item(
        item,
        %{
          status: :confirmed,
          final_name: item.final_name || item.raw_name,
          final_quantity: item.final_quantity || item.quantity,
          final_unit: item.final_unit || item.unit
        },
        authorize?: false,
        tenant: receipt.account_id
      )
    end

    # Create inventory entries from confirmed items
    ReceiptProcessor.create_inventory_entries(receipt)

    confirmed_items =
      Enum.map(items, fn item -> Map.put(item, :status, :confirmed) end)

    socket =
      socket
      |> assign(:step, :complete)
      |> assign(:receipt_items, confirmed_items)

    {:noreply, socket}
  end

  @impl true
  def handle_event("back_to_upload", _, socket) do
    socket =
      socket
      |> assign(:step, :upload)
      |> assign(:receipt, nil)
      |> assign(:receipt_items, [])
      |> assign(:error, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("scan_another", _, socket) do
    {:noreply,
     assign(socket,
       step: :upload,
       receipt: nil,
       receipt_items: [],
       error: nil,
       processing_status: nil
     )}
  end

  @impl true
  def handle_event("open_catalog_search", %{"idx" => idx}, socket) do
    idx = String.to_integer(idx)
    item = Enum.at(socket.assigns.receipt_items, idx)
    query = item.final_name || item.raw_name || ""

    # Pre-populate search results with the item name
    results = search_catalog(query, socket.assigns.current_account.id)

    {:noreply,
     socket
     |> assign(:catalog_search_idx, idx)
     |> assign(:catalog_search_query, query)
     |> assign(:catalog_search_results, results)}
  end

  @impl true
  def handle_event("catalog_search", %{"query" => query}, socket) do
    results = search_catalog(query, socket.assigns.current_account.id)

    {:noreply,
     socket
     |> assign(:catalog_search_query, query)
     |> assign(:catalog_search_results, results)}
  end

  @impl true
  def handle_event(
        "select_catalog_match",
        %{"grocery-item-id" => gi_id, "grocery-item-name" => _name},
        socket
      ) do
    idx = socket.assigns.catalog_search_idx
    receipt = socket.assigns.receipt

    items =
      List.update_at(socket.assigns.receipt_items, idx, fn item ->
        # Update the DB record if it exists
        if item.id do
          Inventory.update_receipt_item(
            item,
            %{grocery_item_id: gi_id, match_confidence: 1.0, user_corrected: true},
            authorize?: false,
            tenant: receipt.account_id
          )
        end

        Map.merge(item, %{grocery_item_id: gi_id, match_confidence: 1.0, user_corrected: true})
      end)

    {:noreply,
     socket
     |> assign(:receipt_items, items)
     |> assign(:catalog_search_idx, nil)
     |> assign(:catalog_search_query, "")
     |> assign(:catalog_search_results, [])}
  end

  @impl true
  def handle_event("create_and_match", _, socket) do
    idx = socket.assigns.catalog_search_idx
    item = Enum.at(socket.assigns.receipt_items, idx)
    receipt = socket.assigns.receipt
    name = item.final_name || item.raw_name

    case Inventory.create_grocery_item(
           receipt.account_id,
           %{name: name, default_unit: item.final_unit || item.unit},
           authorize?: false,
           tenant: receipt.account_id
         ) do
      {:ok, grocery_item} ->
        items =
          List.update_at(socket.assigns.receipt_items, idx, fn item ->
            if item.id do
              Inventory.update_receipt_item(
                item,
                %{grocery_item_id: grocery_item.id, match_confidence: 1.0, user_corrected: true},
                authorize?: false,
                tenant: receipt.account_id
              )
            end

            Map.merge(item, %{
              grocery_item_id: grocery_item.id,
              match_confidence: 1.0,
              user_corrected: true
            })
          end)

        {:noreply,
         socket
         |> assign(:receipt_items, items)
         |> assign(:catalog_search_idx, nil)
         |> assign(:catalog_search_query, "")
         |> assign(:catalog_search_results, [])}

      {:error, _reason} ->
        {:noreply, assign(socket, :error, "Failed to create grocery item '#{name}'")}
    end
  end

  @impl true
  def handle_event("close_catalog_search", _, socket) do
    {:noreply,
     socket
     |> assign(:catalog_search_idx, nil)
     |> assign(:catalog_search_query, "")
     |> assign(:catalog_search_results, [])}
  end

  # ---------------------------------------------------------------------------
  # PubSub handlers for receipt processing
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:receipt_processed, receipt}, socket) do
    account_id = receipt.account_id

    case Inventory.list_receipt_items_for_receipt(receipt.id,
           authorize?: false,
           tenant: account_id
         ) do
      {:ok, items} ->
        # Run item matching against grocery catalog
        matched = ItemMatcher.match_receipt_items(items, account_id)

        # Update items with match results and build display list
        updated_items =
          Enum.map(matched, fn {item, match_result} ->
            case match_result do
              {:ok, match} ->
                Inventory.update_receipt_item(
                  item,
                  %{
                    grocery_item_id: match.item.id,
                    match_confidence: match.confidence
                  },
                  authorize?: false,
                  tenant: account_id
                )

                Map.merge(item, %{
                  grocery_item_id: match.item.id,
                  match_confidence: match.confidence
                })

              _ ->
                item
            end
          end)

        socket =
          socket
          |> assign(:step, :review)
          |> assign(:receipt, receipt)
          |> assign(:receipt_items, updated_items)
          |> assign(:processing_status, "Complete")

        {:noreply, socket}

      _ ->
        {:noreply, assign(socket, step: :review, receipt: receipt, receipt_items: [])}
    end
  end

  @impl true
  def handle_info({:receipt_processing_status, status}, socket) do
    {:noreply, assign(socket, :processing_status, status)}
  end

  @impl true
  def handle_info({:receipt_failed, _receipt, reason}, socket) do
    socket =
      socket
      |> assign(:step, :upload)
      |> assign(:error, "Processing failed: #{inspect(reason)}")

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Helper functions
  # ---------------------------------------------------------------------------

  defp step_class(step, current) do
    steps = [:upload, :processing, :review, :complete]
    step_idx = Enum.find_index(steps, &(&1 == step))
    current_idx = Enum.find_index(steps, &(&1 == current))

    if step_idx <= current_idx, do: "step step-primary", else: "step"
  end

  defp confidence_color(nil), do: "bg-base-300"
  defp confidence_color(c) when is_number(c) and c >= 0.8, do: "bg-success"
  defp confidence_color(c) when is_number(c) and c >= 0.5, do: "bg-warning"
  defp confidence_color(_), do: "bg-error"

  defp format_decimal(nil), do: ""
  defp format_decimal(%Decimal{} = d), do: Decimal.to_string(d)
  defp format_decimal(val), do: "#{val}"

  defp item_status(%{status: status}) when is_atom(status), do: status
  defp item_status(_), do: :pending

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "Invalid file type. Use JPEG, PNG, HEIC, or PDF"
  defp error_to_string(:too_many_files), do: "Only one file at a time"
  defp error_to_string(err), do: "Error: #{inspect(err)}"

  defp search_catalog("", _account_id), do: []

  defp search_catalog(query, account_id) do
    case Inventory.list_grocery_items(authorize?: false, tenant: account_id) do
      {:ok, items} ->
        query_down = String.downcase(query)

        items
        |> Enum.filter(fn item ->
          String.contains?(String.downcase(item.name), query_down)
        end)
        |> Enum.take(10)

      _ ->
        []
    end
  end

  defp format_confidence(nil), do: "?"
  defp format_confidence(c) when is_number(c), do: "#{round(c * 100)}%"
end
