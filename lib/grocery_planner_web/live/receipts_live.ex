defmodule GroceryPlannerWeb.ReceiptsLive do
  @moduledoc """
  LiveView for receipt scanning and OCR processing.

  Allows users to:
  - Upload receipt images
  - Track OCR processing status
  - Review and edit extracted items
  - Create inventory entries from confirmed items
  """
  use GroceryPlannerWeb, :live_view

  on_mount({GroceryPlannerWeb.Auth, :require_authenticated_user})

  alias GroceryPlanner.Inventory
  alias GroceryPlanner.Inventory.Receipt
  alias GroceryPlanner.AiClient

  require Ash.Query

  @poll_interval 2000

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Receipts")
      |> assign(:receipts, [])
      |> assign(:selected_receipt, nil)
      |> assign(:show_upload, false)
      |> assign(:uploading, false)
      |> allow_upload(:receipt_image,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 1,
        max_file_size: 10_000_000
      )

    socket = if connected?(socket), do: load_receipts(socket), else: socket

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case params do
        %{"id" => id} ->
          load_receipt_detail(socket, id)

        _ ->
          assign(socket, :selected_receipt, nil)
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_account={@current_account}
      current_scope={@current_scope}
    >
      <div class="px-4 py-10 sm:px-6 lg:px-8">
        <div class="mb-8 flex items-center justify-between">
          <div>
            <h1 class="text-4xl font-bold text-base-content">Receipt Scanner</h1>
            <p class="mt-2 text-lg text-base-content/70">
              Upload receipts to automatically extract items
            </p>
          </div>
          <button
            phx-click="toggle_upload"
            class="btn btn-primary"
          >
            <.icon name="hero-camera" class="w-5 h-5 mr-2" /> Scan Receipt
          </button>
        </div>

        <%= if @show_upload do %>
          <.upload_panel uploads={@uploads} uploading={@uploading} />
        <% end %>

        <%= if @selected_receipt do %>
          <.receipt_detail
            receipt={@selected_receipt}
            current_account={@current_account}
            current_user={@current_user}
          />
        <% else %>
          <.receipts_list receipts={@receipts} />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # Upload panel component
  attr :uploads, :map, required: true
  attr :uploading, :boolean, default: false

  defp upload_panel(assigns) do
    ~H"""
    <div class="mb-8 bg-base-100 rounded-box shadow-sm border border-base-200 p-6">
      <h2 class="text-lg font-semibold mb-4">Upload Receipt</h2>

      <form id="upload-form" phx-submit="save_upload" phx-change="validate_upload">
        <div class="border-2 border-dashed border-base-300 rounded-lg p-8 text-center hover:border-primary transition-colors">
          <.live_file_input upload={@uploads.receipt_image} class="hidden" />

          <%= if Enum.empty?(@uploads.receipt_image.entries) do %>
            <label for={@uploads.receipt_image.ref} class="cursor-pointer">
              <.icon name="hero-cloud-arrow-up" class="w-12 h-12 mx-auto text-base-content/40" />
              <p class="mt-2 text-sm text-base-content/70">
                Click to upload or drag and drop
              </p>
              <p class="text-xs text-base-content/50">
                JPG, PNG or WebP up to 10MB
              </p>
            </label>
          <% else %>
            <%= for entry <- @uploads.receipt_image.entries do %>
              <div class="flex items-center justify-center gap-4">
                <.live_img_preview entry={entry} class="h-32 rounded-lg" />
                <div class="text-left">
                  <p class="font-medium">{entry.client_name}</p>
                  <p class="text-sm text-base-content/70">
                    {format_bytes(entry.client_size)}
                  </p>
                  <progress class="progress progress-primary w-48" value={entry.progress} max="100" />
                </div>
                <button
                  type="button"
                  phx-click="cancel_upload"
                  phx-value-ref={entry.ref}
                  class="btn btn-ghost btn-sm"
                >
                  <.icon name="hero-x-mark" class="w-4 h-4" />
                </button>
              </div>

              <%= for err <- upload_errors(@uploads.receipt_image, entry) do %>
                <p class="text-error text-sm mt-2">{error_to_string(err)}</p>
              <% end %>
            <% end %>
          <% end %>
        </div>

        <%= for err <- upload_errors(@uploads.receipt_image) do %>
          <p class="text-error text-sm mt-2">{error_to_string(err)}</p>
        <% end %>

        <div class="mt-4 flex justify-end gap-2">
          <button type="button" phx-click="toggle_upload" class="btn btn-ghost">
            Cancel
          </button>
          <button
            type="submit"
            disabled={Enum.empty?(@uploads.receipt_image.entries) || @uploading}
            class="btn btn-primary"
          >
            <%= if @uploading do %>
              <span class="loading loading-spinner loading-sm"></span> Processing...
            <% else %>
              <.icon name="hero-sparkles" class="w-4 h-4 mr-2" /> Extract Items
            <% end %>
          </button>
        </div>
      </form>
    </div>
    """
  end

  # Receipts list component
  attr :receipts, :list, required: true

  defp receipts_list(assigns) do
    ~H"""
    <div class="bg-base-100 rounded-box shadow-sm border border-base-200">
      <%= if Enum.empty?(@receipts) do %>
        <div class="p-12 text-center">
          <.icon name="hero-document-text" class="w-16 h-16 mx-auto text-base-content/20" />
          <h3 class="mt-4 text-lg font-medium text-base-content">No receipts yet</h3>
          <p class="mt-2 text-base-content/70">
            Upload a receipt to get started
          </p>
        </div>
      <% else %>
        <div class="divide-y divide-base-200">
          <%= for receipt <- @receipts do %>
            <.link
              patch={~p"/receipts/#{receipt.id}"}
              class="flex items-center gap-4 p-4 hover:bg-base-200/50 transition-colors"
            >
              <div class="w-16 h-16 bg-base-200 rounded-lg flex items-center justify-center overflow-hidden">
                <%= if receipt.image_path do %>
                  <img src={receipt.image_path} class="w-full h-full object-cover" />
                <% else %>
                  <.icon name="hero-document-text" class="w-8 h-8 text-base-content/40" />
                <% end %>
              </div>

              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2">
                  <p class="font-medium truncate">
                    {receipt.merchant || "Unknown Merchant"}
                  </p>
                  <.status_badge status={receipt.status} />
                </div>
                <p class="text-sm text-base-content/70">
                  <%= if receipt.scanned_date do %>
                    {Calendar.strftime(receipt.scanned_date, "%B %d, %Y")}
                  <% else %>
                    {Calendar.strftime(receipt.created_at, "%B %d, %Y at %I:%M %p")}
                  <% end %>
                </p>
                <%= if receipt.items && length(receipt.items) > 0 do %>
                  <p class="text-sm text-base-content/50">
                    {length(receipt.items)} items
                  </p>
                <% end %>
              </div>

              <div class="text-right">
                <%= if receipt.total_amount do %>
                  <p class="font-semibold">
                    {Money.to_string(receipt.total_amount)}
                  </p>
                <% end %>
              </div>

              <.icon name="hero-chevron-right" class="w-5 h-5 text-base-content/40" />
            </.link>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Receipt detail component
  attr :receipt, :map, required: true
  attr :current_account, :map, required: true
  attr :current_user, :map, required: true

  defp receipt_detail(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-4">
        <.link patch={~p"/receipts"} class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
        </.link>
        <h2 class="text-2xl font-bold">
          {@receipt.merchant || "Receipt Details"}
        </h2>
        <.status_badge status={@receipt.status} />
      </div>

      <%= case @receipt.status do %>
        <% :pending -> %>
          <.processing_state message="Waiting to process..." />
        <% :processing -> %>
          <.processing_state message="Extracting items from receipt..." />
        <% :failed -> %>
          <.error_state message="Failed to process receipt. Please try again." />
        <% status when status in [:review, :completed] -> %>
          <.review_panel receipt={@receipt} />
      <% end %>
    </div>
    """
  end

  defp processing_state(assigns) do
    ~H"""
    <div class="bg-base-100 rounded-box shadow-sm border border-base-200 p-12 text-center">
      <span class="loading loading-spinner loading-lg text-primary"></span>
      <p class="mt-4 text-lg font-medium">{@message}</p>
      <p class="text-base-content/70">This may take a few moments</p>
    </div>
    """
  end

  defp error_state(assigns) do
    ~H"""
    <div class="bg-error/10 rounded-box border border-error/20 p-8 text-center">
      <.icon name="hero-exclamation-triangle" class="w-12 h-12 mx-auto text-error" />
      <p class="mt-4 text-lg font-medium text-error">{@message}</p>
      <button phx-click="retry_processing" class="btn btn-error btn-outline mt-4">
        <.icon name="hero-arrow-path" class="w-4 h-4 mr-2" /> Retry
      </button>
    </div>
    """
  end

  attr :receipt, :map, required: true

  defp review_panel(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <div class="bg-base-100 rounded-box shadow-sm border border-base-200 p-6">
        <h3 class="font-semibold mb-4">Receipt Image</h3>
        <%= if @receipt.image_path do %>
          <img src={@receipt.image_path} class="w-full rounded-lg" />
        <% else %>
          <div class="bg-base-200 rounded-lg h-64 flex items-center justify-center">
            <.icon name="hero-photo" class="w-16 h-16 text-base-content/20" />
          </div>
        <% end %>

        <div class="mt-4 space-y-2">
          <%= if @receipt.scanned_date do %>
            <p class="text-sm">
              <span class="text-base-content/70">Date:</span>
              {Calendar.strftime(@receipt.scanned_date, "%B %d, %Y")}
            </p>
          <% end %>
          <%= if @receipt.total_amount do %>
            <p class="text-sm">
              <span class="text-base-content/70">Total:</span>
              <span class="font-semibold">{Money.to_string(@receipt.total_amount)}</span>
            </p>
          <% end %>
        </div>
      </div>

      <div class="bg-base-100 rounded-box shadow-sm border border-base-200 p-6">
        <div class="flex items-center justify-between mb-4">
          <h3 class="font-semibold">Extracted Items</h3>
          <span class="badge badge-ghost">
            {length(@receipt.items || [])} items
          </span>
        </div>

        <%= if Enum.empty?(@receipt.items || []) do %>
          <p class="text-base-content/70 text-center py-8">
            No items extracted
          </p>
        <% else %>
          <div class="space-y-3">
            <%= for {item, index} <- Enum.with_index(@receipt.items || []) do %>
              <div class="flex items-center gap-3 p-3 bg-base-200/50 rounded-lg">
                <div class="flex-1">
                  <p class="font-medium">{item.name}</p>
                  <p class="text-sm text-base-content/70">
                    {item.quantity} {item.unit}
                    <%= if item.price do %>
                      · {Money.to_string(item.price)}
                    <% end %>
                  </p>
                </div>
                <%= if item.confidence do %>
                  <.confidence_indicator value={item.confidence} />
                <% end %>
                <button
                  phx-click="remove_item"
                  phx-value-index={index}
                  class="btn btn-ghost btn-xs"
                >
                  <.icon name="hero-x-mark" class="w-4 h-4" />
                </button>
              </div>
            <% end %>
          </div>
        <% end %>

        <%= if @receipt.status == :review do %>
          <div class="mt-6 flex gap-2">
            <button phx-click="add_to_inventory" class="btn btn-primary flex-1">
              <.icon name="hero-plus" class="w-4 h-4 mr-2" /> Add to Inventory
            </button>
            <button phx-click="discard_receipt" class="btn btn-ghost">
              Discard
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    {class, text} =
      case assigns.status do
        :pending -> {"badge-ghost", "Pending"}
        :processing -> {"badge-info", "Processing"}
        :review -> {"badge-warning", "Review"}
        :completed -> {"badge-success", "Completed"}
        :failed -> {"badge-error", "Failed"}
        _ -> {"badge-ghost", "Unknown"}
      end

    assigns = assign(assigns, :class, class)
    assigns = assign(assigns, :text, text)

    ~H"""
    <span class={"badge #{@class}"}>{@text}</span>
    """
  end

  attr :value, :float, required: true

  defp confidence_indicator(assigns) do
    color =
      cond do
        assigns.value >= 0.9 -> "text-success"
        assigns.value >= 0.7 -> "text-warning"
        true -> "text-error"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <span class={"text-xs #{@color}"}>
      {round(@value * 100)}%
    </span>
    """
  end

  # Event handlers

  @impl true
  def handle_event("toggle_upload", _, socket) do
    {:noreply, assign(socket, :show_upload, !socket.assigns.show_upload)}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :receipt_image, ref)}
  end

  @impl true
  def handle_event("save_upload", _params, socket) do
    socket = assign(socket, :uploading, true)

    uploaded_files =
      consume_uploaded_entries(socket, :receipt_image, fn %{path: path}, entry ->
        # Generate a unique filename
        ext = Path.extname(entry.client_name)
        filename = "receipt_#{Ecto.UUID.generate()}#{ext}"

        # Store in priv/static/uploads (for dev) - production would use S3
        dest_dir = Path.join([:code.priv_dir(:grocery_planner), "static", "uploads"])
        File.mkdir_p!(dest_dir)
        dest = Path.join(dest_dir, filename)

        File.cp!(path, dest)
        {:ok, "/uploads/#{filename}"}
      end)

    case uploaded_files do
      [image_path] ->
        # Create receipt record
        case Inventory.create_receipt(
               socket.assigns.current_account.id,
               %{image_path: image_path},
               actor: socket.assigns.current_user
             ) do
          {:ok, receipt} ->
            # Submit to AI service for processing
            socket = start_ocr_processing(socket, receipt)

            socket =
              socket
              |> assign(:uploading, false)
              |> assign(:show_upload, false)
              |> put_flash(:info, "Receipt uploaded! Processing...")
              |> push_patch(to: ~p"/receipts/#{receipt.id}")

            {:noreply, socket}

          {:error, error} ->
            socket =
              socket
              |> assign(:uploading, false)
              |> put_flash(:error, "Failed to save receipt: #{inspect(error)}")

            {:noreply, socket}
        end

      _ ->
        {:noreply, assign(socket, :uploading, false)}
    end
  end

  @impl true
  def handle_event("remove_item", %{"index" => index}, socket) do
    index = String.to_integer(index)
    receipt = socket.assigns.selected_receipt
    items = List.delete_at(receipt.items || [], index)

    case Inventory.update_receipt(receipt, %{items: items}, actor: socket.assigns.current_user) do
      {:ok, updated_receipt} ->
        {:noreply, assign(socket, :selected_receipt, updated_receipt)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove item")}
    end
  end

  @impl true
  def handle_event("add_to_inventory", _, socket) do
    receipt = socket.assigns.selected_receipt
    account_id = socket.assigns.current_account.id
    actor = socket.assigns.current_user

    # Create inventory entries from receipt items
    results =
      (receipt.items || [])
      |> Enum.map(fn item ->
        create_inventory_entry_from_item(item, account_id, receipt.scanned_date, actor)
      end)

    success_count = Enum.count(results, &match?({:ok, _}, &1))
    error_count = Enum.count(results, &match?({:error, _}, &1))

    # Mark receipt as completed
    case Inventory.update_receipt(receipt, %{status: :completed}, actor: actor) do
      {:ok, updated_receipt} ->
        message =
          cond do
            error_count == 0 -> "#{success_count} items added to inventory!"
            success_count == 0 -> "Failed to add items to inventory"
            true -> "#{success_count} items added, #{error_count} failed"
          end

        socket =
          socket
          |> assign(:selected_receipt, updated_receipt)
          |> load_receipts()
          |> put_flash(if(error_count == 0, do: :info, else: :warning), message)

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update receipt")}
    end
  end

  @impl true
  def handle_event("discard_receipt", _, socket) do
    receipt = socket.assigns.selected_receipt

    case Inventory.destroy_receipt(receipt, actor: socket.assigns.current_user) do
      :ok ->
        socket =
          socket
          |> load_receipts()
          |> put_flash(:info, "Receipt discarded")
          |> push_patch(to: ~p"/receipts")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to discard receipt")}
    end
  end

  @impl true
  def handle_event("retry_processing", _, socket) do
    receipt = socket.assigns.selected_receipt
    socket = start_ocr_processing(socket, receipt)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:poll_job, job_id, receipt_id}, socket) do
    context = %{
      tenant_id: socket.assigns.current_account.id,
      user_id: socket.assigns.current_user.id
    }

    case AiClient.get_job(job_id, context) do
      {:ok, %{"status" => "succeeded", "output_payload" => output}} ->
        update_receipt_with_results(socket, receipt_id, output)

      {:ok, %{"status" => "failed", "error_message" => error}} ->
        mark_receipt_failed(socket, receipt_id, error)

      {:ok, %{"status" => status}} when status in ["queued", "running"] ->
        # Continue polling
        Process.send_after(self(), {:poll_job, job_id, receipt_id}, @poll_interval)
        {:noreply, socket}

      {:error, _} ->
        mark_receipt_failed(socket, receipt_id, "Connection error")
    end
  end

  # Private helpers

  defp load_receipts(socket) do
    receipts =
      Receipt
      |> Ash.Query.filter(account_id == ^socket.assigns.current_account.id)
      |> Ash.Query.sort(created_at: :desc)
      |> Ash.read!(actor: socket.assigns.current_user)

    assign(socket, :receipts, receipts)
  end

  defp load_receipt_detail(socket, id) do
    case Inventory.get_receipt(id, actor: socket.assigns.current_user) do
      {:ok, receipt} ->
        socket = assign(socket, :selected_receipt, receipt)

        # If processing, start polling
        if receipt.status == :processing && receipt.job_id do
          Process.send_after(self(), {:poll_job, receipt.job_id, receipt.id}, @poll_interval)
        end

        socket

      {:error, _} ->
        socket
        |> put_flash(:error, "Receipt not found")
        |> push_patch(to: ~p"/receipts")
    end
  end

  defp start_ocr_processing(socket, receipt) do
    context = %{
      tenant_id: socket.assigns.current_account.id,
      user_id: socket.assigns.current_user.id
    }

    # Read image and encode to base64
    image_path =
      Path.join([
        :code.priv_dir(:grocery_planner),
        "static",
        String.trim_leading(receipt.image_path, "/")
      ])

    case File.read(image_path) do
      {:ok, image_data} ->
        image_base64 = Base.encode64(image_data)

        case AiClient.submit_job("receipt_extraction", %{image_base64: image_base64}, context) do
          {:ok, %{"job_id" => job_id}} ->
            # Update receipt with job_id and status
            {:ok, _} =
              Inventory.update_receipt(
                receipt,
                %{
                  status: :processing,
                  job_id: job_id
                },
                actor: socket.assigns.current_user
              )

            # Start polling
            Process.send_after(self(), {:poll_job, job_id, receipt.id}, @poll_interval)
            socket

          {:error, _} ->
            Inventory.update_receipt(receipt, %{status: :failed},
              actor: socket.assigns.current_user
            )

            put_flash(socket, :error, "Failed to start processing")
        end

      {:error, _} ->
        Inventory.update_receipt(receipt, %{status: :failed}, actor: socket.assigns.current_user)
        put_flash(socket, :error, "Failed to read image")
    end
  end

  defp update_receipt_with_results(socket, receipt_id, output) do
    items =
      (output["items"] || [])
      |> Enum.map(fn item ->
        %{
          name: item["name"],
          quantity: item["quantity"],
          unit: item["unit"],
          price: if(item["price"], do: Money.new(:USD, item["price"]), else: nil),
          confidence: item["confidence"]
        }
      end)

    total_amount =
      if output["total"] do
        Money.new(:USD, output["total"])
      end

    updates = %{
      status: :review,
      items: items,
      merchant: output["merchant"],
      total_amount: total_amount,
      scanned_date: parse_date(output["date"])
    }

    case Inventory.get_receipt(receipt_id, actor: socket.assigns.current_user) do
      {:ok, receipt} ->
        case Inventory.update_receipt(receipt, updates, actor: socket.assigns.current_user) do
          {:ok, updated_receipt} ->
            socket =
              socket
              |> assign(:selected_receipt, updated_receipt)
              |> load_receipts()

            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update receipt")}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp mark_receipt_failed(socket, receipt_id, _error) do
    case Inventory.get_receipt(receipt_id, actor: socket.assigns.current_user) do
      {:ok, receipt} ->
        Inventory.update_receipt(receipt, %{status: :failed}, actor: socket.assigns.current_user)

        socket =
          socket
          |> assign(:selected_receipt, %{receipt | status: :failed})
          |> put_flash(:error, "Processing failed")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "Invalid file type. Please use JPG, PNG, or WebP"
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(err), do: "Error: #{inspect(err)}"

  defp create_inventory_entry_from_item(item, account_id, purchase_date, actor) do
    alias GroceryPlanner.Inventory.GroceryItem

    # Find or create a GroceryItem by name
    grocery_item =
      case find_grocery_item_by_name(item.name, account_id, actor) do
        {:ok, existing} ->
          existing

        :not_found ->
          # Create new grocery item
          case Inventory.create_grocery_item(account_id, %{name: item.name}, actor: actor) do
            {:ok, new_item} -> new_item
            {:error, _} -> nil
          end
      end

    if grocery_item do
      # Create inventory entry
      entry_attrs = %{
        quantity: item.quantity || Decimal.new(1),
        unit: item.unit,
        purchase_price: item.price,
        purchase_date: purchase_date,
        grocery_item_id: grocery_item.id
      }

      Inventory.create_inventory_entry(account_id, entry_attrs, actor: actor)
    else
      {:error, :no_grocery_item}
    end
  end

  defp find_grocery_item_by_name(name, account_id, actor) do
    alias GroceryPlanner.Inventory.GroceryItem

    result =
      GroceryItem
      |> Ash.Query.filter(account_id == ^account_id)
      |> Ash.Query.filter(fragment("lower(?) = lower(?)", name, ^name))
      |> Ash.Query.limit(1)
      |> Ash.read(actor: actor)

    case result do
      {:ok, [item]} -> {:ok, item}
      {:ok, []} -> :not_found
      {:error, _} -> :not_found
    end
  end
end
