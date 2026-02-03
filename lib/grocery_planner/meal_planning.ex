defmodule GroceryPlanner.MealPlanning do
  @moduledoc false
  use Ash.Domain,
    extensions: [AshJsonApi.Domain]

  json_api do
    prefix "/api/json"
  end

  resources do
    resource GroceryPlanner.MealPlanning.MealPlan do
      define :create_meal_plan, action: :create, args: [:account_id]
      define :list_meal_plans, action: :read

      define :list_meal_plans_by_date_range,
        action: :by_date_range,
        args: [:start_date, :end_date]

      define :list_recent_meal_plans, action: :recent, args: [:since]
      define :get_meal_plan, action: :read, get_by: [:id]
      define :update_meal_plan, action: :update
      define :destroy_meal_plan, action: :destroy
      define :complete_meal_plan, action: :complete
      define :skip_meal_plan, action: :skip
    end

    resource GroceryPlanner.MealPlanning.MealPlanTemplate do
      define :create_meal_plan_template, action: :create, args: [:account_id]
      define :get_meal_plan_template, action: :read, get_by: [:id]
      define :update_meal_plan_template, action: :update
      define :destroy_meal_plan_template, action: :destroy
      define :activate_meal_plan_template, action: :activate
      define :deactivate_meal_plan_template, action: :deactivate
      define :list_meal_plan_templates, action: :read
    end

    resource GroceryPlanner.MealPlanning.MealPlanTemplateEntry do
      define :create_meal_plan_template_entry, action: :create, args: [:account_id]
      define :get_meal_plan_template_entry, action: :read, get_by: [:id]
      define :list_meal_plan_template_entries, action: :read
      define :list_entries_by_template, action: :list_by_template, args: [:template_id]
      define :update_meal_plan_template_entry, action: :update
      define :destroy_meal_plan_template_entry, action: :destroy
    end

    resource GroceryPlanner.MealPlanning.MealPlanVoteSession do
      define :create_vote_session, action: :start, args: [:account_id]
      define :list_vote_sessions, action: :read
      define :get_vote_session, action: :read, get_by: [:id]
      define :update_vote_session, action: :update
      define :mark_session_processed, action: :mark_processed
    end

    resource GroceryPlanner.MealPlanning.MealPlanVoteEntry do
      define :create_vote_entry,
        action: :vote,
        args: [:account_id, :vote_session_id, :recipe_id, :user_id]

      define :list_vote_entries, action: :read
      define :list_entries_for_session, action: :by_session, args: [:vote_session_id]
      define :destroy_vote_entry, action: :destroy
    end
  end
end
