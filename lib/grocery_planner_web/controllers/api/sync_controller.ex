defmodule GroceryPlannerWeb.Api.SyncController do
  @moduledoc """
  Controller for batch sync operations.

  Supports creating, updating, and deleting multiple resources in a single
  request, which is essential for mobile clients syncing offline changes.
  """
  use GroceryPlannerWeb, :controller

  alias GroceryPlanner.Inventory
  alias GroceryPlanner.MealPlanning
  alias GroceryPlanner.Recipes
  alias GroceryPlanner.Shopping

  # Maps client type strings to {domain_module, resource_name_atom}
  @resource_types %{
    "shopping_list" => {Shopping, :shopping_list},
    "shopping_list_item" => {Shopping, :shopping_list_item},
    "grocery_item" => {Inventory, :grocery_item},
    "inventory_entry" => {Inventory, :inventory_entry},
    "recipe" => {Recipes, :recipe},
    "recipe_ingredient" => {Recipes, :recipe_ingredient},
    "meal_plan" => {MealPlanning, :meal_plan},
    "meal_plan_template" => {MealPlanning, :meal_plan_template},
    "meal_plan_template_entry" => {MealPlanning, :meal_plan_template_entry},
    "vote_session" => {MealPlanning, :vote_session},
    "vote_entry" => {MealPlanning, :vote_entry}
  }

  # Resources that don't support update
  @no_update_types ["vote_entry"]

  @doc """
  Process a batch of sync operations.

  Accepts an array of create/update/delete operations and returns
  per-operation results. Optionally atomic (all-or-nothing).
  """
  def batch(conn, %{"operations" => operations} = params) when is_list(operations) do
    actor = conn.assigns[:current_user]
    tenant = Ash.PlugHelpers.get_tenant(conn)
    atomic = Map.get(params, "atomic", false)
    opts = [actor: actor, tenant: tenant]

    if atomic do
      execute_atomic(operations, opts, conn)
    else
      results = Enum.map(operations, &execute_operation(&1, opts))
      send_batch_response(conn, 200, results)
    end
  end

  def batch(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      errors: [
        %{
          id: Ash.UUID.generate(),
          status: "400",
          code: "invalid_request",
          title: "Bad Request",
          detail: "Request must include an 'operations' array"
        }
      ],
      jsonapi: %{version: "1.0"}
    })
  end

  @doc """
  Returns sync status including server timestamp.
  """
  def status(conn, _params) do
    json(conn, %{
      data: %{
        server_time: DateTime.utc_now() |> DateTime.to_iso8601(),
        api_version: "1.0"
      },
      jsonapi: %{version: "1.0"}
    })
  end

  # --- Atomic execution ---

  defp execute_atomic(operations, opts, conn) do
    result =
      GroceryPlanner.Repo.transaction(fn ->
        operations
        |> Enum.reduce_while([], fn op, acc ->
          case execute_operation(op, opts) do
            %{status: "error"} = error_result ->
              {:halt, {:error, Enum.reverse([error_result | acc])}}

            ok_result ->
              {:cont, [ok_result | acc]}
          end
        end)
        |> case do
          {:error, partial} -> GroceryPlanner.Repo.rollback(partial)
          results -> Enum.reverse(results)
        end
      end)

    case result do
      {:ok, results} ->
        send_batch_response(conn, 200, results)

      {:error, partial_results} ->
        send_batch_response(conn, 422, partial_results)
    end
  end

  defp send_batch_response(conn, status_code, results) do
    conn
    |> put_status(status_code)
    |> json(%{
      results: results,
      server_time: DateTime.utc_now() |> DateTime.to_iso8601(),
      jsonapi: %{version: "1.0"}
    })
  end

  # --- Operation dispatch ---

  defp execute_operation(%{"op" => "create", "type" => type, "data" => data} = op, opts)
       when is_map_key(@resource_types, type) do
    temp_id = Map.get(op, "temp_id")

    case do_create(type, data, opts) do
      {:ok, record} ->
        build_ok_result("create", type, temp_id, %{
          id: record.id,
          data: serialize_record(record)
        })

      {:error, error} ->
        build_error_result("create", type, temp_id, error)
    end
  end

  defp execute_operation(%{"op" => "update", "type" => type, "id" => id, "data" => data}, opts)
       when is_map_key(@resource_types, type) do
    if type in @no_update_types do
      %{
        op: "update",
        type: type,
        id: id,
        status: "error",
        error: %{code: "unsupported_operation", detail: "Update is not supported for #{type}"}
      }
    else
      case do_update(type, id, data, opts) do
        {:ok, record} ->
          %{op: "update", type: type, id: id, status: "ok", data: serialize_record(record)}

        {:error, error} ->
          %{op: "update", type: type, id: id, status: "error", error: format_error(error)}
      end
    end
  end

  defp execute_operation(%{"op" => "delete", "type" => type, "id" => id}, opts)
       when is_map_key(@resource_types, type) do
    case do_delete(type, id, opts) do
      {:ok, _record} ->
        %{op: "delete", type: type, id: id, status: "ok"}

      {:error, error} ->
        %{op: "delete", type: type, id: id, status: "error", error: format_error(error)}
    end
  end

  defp execute_operation(%{"type" => type}, _opts)
       when not is_map_key(@resource_types, type) do
    %{
      type: type,
      status: "error",
      error: %{code: "unknown_type", detail: "Unknown resource type: #{type}"}
    }
  end

  defp execute_operation(op, _opts) do
    %{
      op: Map.get(op, "op", "unknown"),
      type: Map.get(op, "type", "unknown"),
      status: "error",
      error: %{code: "invalid_operation", detail: "Invalid operation format"}
    }
  end

  # --- Create ---

  defp do_create("inventory_entry", data, opts) do
    {grocery_item_id, attrs} = Map.pop(data, "grocery_item_id")
    Inventory.create_inventory_entry(opts[:tenant], grocery_item_id, attrs, opts)
  end

  defp do_create("vote_entry", data, opts) do
    {vote_session_id, attrs} = Map.pop(data, "vote_session_id")
    MealPlanning.create_vote_entry_from_api(vote_session_id, attrs, opts)
  end

  defp do_create(type, data, opts) do
    {domain, resource} = Map.fetch!(@resource_types, type)
    apply(domain, :"create_#{resource}", [opts[:tenant], data, opts])
  end

  # --- Get ---

  defp do_get(type, id, opts) do
    {domain, resource} = Map.fetch!(@resource_types, type)
    apply(domain, :"get_#{resource}", [id, opts])
  end

  # --- Update ---

  defp do_update(type, id, data, opts) do
    with {:ok, record} <- do_get(type, id, opts) do
      {domain, resource} = Map.fetch!(@resource_types, type)
      apply(domain, :"update_#{resource}", [record, data, opts])
    end
  end

  # --- Delete ---

  defp do_delete(type, id, opts) do
    with {:ok, record} <- do_get(type, id, opts) do
      {domain, resource} = Map.fetch!(@resource_types, type)
      apply(domain, :"destroy_#{resource}", [record, opts])
    end
  end

  # --- Serialization ---

  defp serialize_record(record) do
    %{
      id: record.id,
      created_at: format_datetime(Map.get(record, :created_at)),
      updated_at: format_datetime(Map.get(record, :updated_at)),
      deleted_at: format_datetime(Map.get(record, :deleted_at))
    }
  end

  defp format_datetime(nil), do: nil
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp build_ok_result(op, type, temp_id, extras) do
    base = Map.merge(%{op: op, type: type, status: "ok"}, extras)
    if temp_id, do: Map.put(base, :temp_id, temp_id), else: base
  end

  defp build_error_result(op, type, temp_id, error) do
    base = %{op: op, type: type, status: "error", error: format_error(error)}
    if temp_id, do: Map.put(base, :temp_id, temp_id), else: base
  end

  defp format_error(error) when is_exception(error) do
    %{code: "operation_failed", detail: Exception.message(error)}
  end

  defp format_error(error) when is_binary(error) do
    %{code: "operation_failed", detail: error}
  end

  defp format_error(error) do
    %{code: "operation_failed", detail: inspect(error)}
  end
end
