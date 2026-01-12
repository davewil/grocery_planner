defmodule GroceryPlannerWeb.MealPlannerLive.UndoSystem do
  @max_stack_size 20

  defstruct [:undo_stack, :redo_stack, :toast]

  def new do
    %__MODULE__{
      undo_stack: [],
      redo_stack: [],
      toast: nil
    }
  end

  def push_undo(system, action, message) do
    %{
      system
      | undo_stack: Enum.take([action | system.undo_stack], @max_stack_size),
        redo_stack: [],
        toast: %{message: message, action: :undo, expires_at: now_plus(5)}
    }
  end

  def undo(system) do
    case system.undo_stack do
      [] ->
        {nil, system}

      [action | rest] ->
        {action,
         %{
           system
           | undo_stack: rest,
             redo_stack: Enum.take([action | system.redo_stack], @max_stack_size),
             toast: %{message: "Action undone", action: nil, expires_at: now_plus(3)}
         }}
    end
  end

  def redo(system) do
    case system.redo_stack do
      [] ->
        {nil, system}

      [action | rest] ->
        {action,
         %{
           system
           | redo_stack: rest,
             undo_stack: Enum.take([action | system.undo_stack], @max_stack_size),
             toast: %{message: "Action redone", action: nil, expires_at: now_plus(3)}
         }}
    end
  end

  def clear_toast(system), do: %{system | toast: nil}

  defp now_plus(seconds), do: DateTime.add(DateTime.utc_now(), seconds)
end

defmodule GroceryPlannerWeb.MealPlannerLive.UndoActions do
  alias GroceryPlanner.MealPlanning

  def create_meal(meal_id), do: {:create_meal, meal_id}
  def delete_meal(meal_data), do: {:delete_meal, meal_data}
  def move_meal(meal_id, from, to), do: {:move_meal, meal_id, from, to}

  def update_meal(meal_id, old_attrs, new_attrs),
    do: {:update_meal, meal_id, old_attrs, new_attrs}

  def apply_undo({:create_meal, meal_id}, actor, tenant) do
    case MealPlanning.get_meal_plan(meal_id, actor: actor, tenant: tenant) do
      {:ok, meal_plan} ->
        MealPlanning.destroy_meal_plan(meal_plan, actor: actor)

      {:error, _} ->
        {:error, :not_found}
    end
  end

  def apply_undo({:delete_meal, meal_data}, actor, tenant) do
    MealPlanning.create_meal_plan(tenant, meal_data, actor: actor, tenant: tenant)
  end

  def apply_undo({:move_meal, meal_id, from, _to}, actor, tenant) do
    with {:ok, meal_plan} <- MealPlanning.get_meal_plan(meal_id, actor: actor, tenant: tenant) do
      MealPlanning.update_meal_plan(
        meal_plan,
        %{
          scheduled_date: from.date,
          meal_type: from.meal_type
        },
        actor: actor
      )
    end
  end

  def apply_undo({:update_meal, meal_id, old_attrs, _new_attrs}, actor, tenant) do
    with {:ok, meal_plan} <- MealPlanning.get_meal_plan(meal_id, actor: actor, tenant: tenant) do
      MealPlanning.update_meal_plan(meal_plan, old_attrs, actor: actor)
    end
  end
end
