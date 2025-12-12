defmodule GroceryPlanner.MealPlanning.MealPlanTemplatesTest do
  use GroceryPlanner.DataCase

  alias GroceryPlanner.MealPlanning
  alias GroceryPlanner.MealPlanning.MealPlanTemplate
  alias GroceryPlanner.MealPlanning.MealPlanTemplateEntry
  import GroceryPlanner.InventoryTestHelpers

  setup do
    account = create_account()
    user = create_user(account)
    %{account: account, user: user}
  end

  defp create_recipe(account, _user, attrs \\ %{}) do
    default_attrs = %{
      name: "Test Recipe #{System.unique_integer()}",
      description: "A delicious test recipe",
      instructions: "Mix ingredients and cook.",
      prep_time_minutes: 10,
      cook_time_minutes: 20,
      servings: 4,
      difficulty: :medium
    }
    attrs = Map.merge(default_attrs, attrs)

    {:ok, recipe} =
      GroceryPlanner.Recipes.create_recipe(
        account.id,
        attrs,
        authorize?: false,
        tenant: account.id
      )
    recipe
  end

  describe "meal plan templates" do
    test "create_meal_plan_template/2 creates a template", %{account: account, user: user} do
      assert {:ok, %MealPlanTemplate{} = template} =
               MealPlanning.create_meal_plan_template(
                 account.id,
                 %{name: "Weekly Standard"},
                 actor: user,
                 tenant: account.id
               )

      assert template.name == "Weekly Standard"
      assert template.is_active == false
      assert template.account_id == account.id
    end

    test "activate_meal_plan_template/1 activates a template", %{account: account, user: user} do
      {:ok, template} =
        MealPlanning.create_meal_plan_template(
          account.id,
          %{name: "Weekly Standard"},
          actor: user,
          tenant: account.id
        )

      assert template.is_active == false

      {:ok, activated_template} =
        MealPlanning.activate_meal_plan_template(template, actor: user, tenant: account.id)

      assert activated_template.is_active == true
    end

    test "deactivate_meal_plan_template/1 deactivates a template", %{account: account, user: user} do
      {:ok, template} =
        MealPlanning.create_meal_plan_template(
          account.id,
          %{name: "Weekly Standard", is_active: true},
          actor: user,
          tenant: account.id
        )

      assert template.is_active == true

      {:ok, deactivated_template} =
        MealPlanning.deactivate_meal_plan_template(template, actor: user, tenant: account.id)

      assert deactivated_template.is_active == false
    end
  end

  describe "meal plan template entries" do
    setup %{account: account, user: user} do
      {:ok, template} =
        MealPlanning.create_meal_plan_template(
          account.id,
          %{name: "Weekly Standard"},
          actor: user,
          tenant: account.id
        )
      
      recipe = create_recipe(account, user)

      %{template: template, recipe: recipe}
    end

    test "create_meal_plan_template_entry/2 adds entry to template", %{
      account: account,
      user: user,
      template: template,
      recipe: recipe
    } do
      assert {:ok, %MealPlanTemplateEntry{} = entry} =
               MealPlanning.create_meal_plan_template_entry(
                 account.id,
                 %{
                   template_id: template.id,
                   recipe_id: recipe.id,
                   day_of_week: 1, # Monday
                   meal_type: :dinner,
                   servings: 4
                 },
                 actor: user,
                 tenant: account.id
               )

      assert entry.day_of_week == 1
      assert entry.meal_type == :dinner
      assert entry.recipe_id == recipe.id
      assert entry.template_id == template.id
    end
  end
end
