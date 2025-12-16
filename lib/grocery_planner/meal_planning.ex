defmodule GroceryPlanner.MealPlanning do
  use Ash.Domain,
    extensions: [AshJsonApi.Domain]

  json_api do
    prefix "/api/json"
  end

  resources do
    resource GroceryPlanner.MealPlanning.MealPlan do
      define :create_meal_plan, action: :create, args: [:account_id]
      define :list_meal_plans, action: :read
      define :get_meal_plan, action: :read, get_by: [:id]
      define :update_meal_plan, action: :update
      define :destroy_meal_plan, action: :destroy
      define :complete_meal_plan, action: :complete
      define :skip_meal_plan, action: :skip
    end

    resource GroceryPlanner.MealPlanning.MealPlanTemplate do
      define :create_meal_plan_template, action: :create, args: [:account_id]
      define :activate_meal_plan_template, action: :activate
      define :deactivate_meal_plan_template, action: :deactivate
      define :list_meal_plan_templates, action: :read
    end

    resource GroceryPlanner.MealPlanning.MealPlanTemplateEntry do
      define :create_meal_plan_template_entry, action: :create, args: [:account_id]
      define :list_meal_plan_template_entries, action: :read
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
      define :destroy_vote_entry, action: :destroy
    end
  end
end
