defmodule GroceryPlanner.MealPlanning.MealPlanTemplateEntry do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.MealPlanning,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    table "meal_plan_template_entries"
    repo GroceryPlanner.Repo
  end

  json_api do
    type "meal_plan_template_entry"

    routes do
      base("/meal_plan_templates/:template_id/entries")

      index :list_by_template
      get(:read)
      post(:create_from_api)
      patch(:update)
      delete(:destroy)
    end
  end

  code_interface do
    domain GroceryPlanner.MealPlanning

    define :create_meal_plan_template_entry, action: :create
    define :get_meal_plan_template_entry, action: :read, get_by: [:id]
    define :list_meal_plan_template_entries, action: :read
    define :list_entries_by_template, action: :list_by_template, args: [:template_id]
    define :update_meal_plan_template_entry, action: :update
    define :destroy_meal_plan_template_entry, action: :destroy
  end

  actions do
    defaults [:read, :destroy]

    read :list_by_template do
      argument :template_id, :uuid, allow_nil?: false

      filter expr(template_id == ^arg(:template_id))
    end

    create :create do
      accept [
        :template_id,
        :recipe_id,
        :day_of_week,
        :meal_type,
        :servings
      ]

      argument :account_id, :uuid, allow_nil?: false

      change set_attribute(:account_id, arg(:account_id))
    end

    create :create_from_api do
      accept [
        :recipe_id,
        :day_of_week,
        :meal_type,
        :servings
      ]

      argument :template_id, :uuid, allow_nil?: false

      change fn changeset, context ->
        template_id = Ash.Changeset.get_argument(changeset, :template_id)
        tenant = context.tenant

        opts = [authorize?: false]
        opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

        case GroceryPlanner.MealPlanning.get_meal_plan_template(template_id, opts) do
          {:ok, template} ->
            changeset
            |> Ash.Changeset.manage_relationship(:template, template, type: :append)
            |> Ash.Changeset.change_attribute(:account_id, template.account_id)

          {:error, _} ->
            Ash.Changeset.add_error(changeset, field: :template_id, message: "not found")
        end
      end
    end

    update :update do
      accept [
        :recipe_id,
        :day_of_week,
        :meal_type,
        :servings
      ]

      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action_type(:create) do
      # For create, the parent template lookup already validates access
      authorize_if always()
    end

    policy action_type([:update, :destroy]) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end
  end

  multitenancy do
    strategy :attribute
    attribute :account_id
  end

  attributes do
    uuid_primary_key :id

    attribute :day_of_week, :integer do
      constraints min: 0, max: 6
      allow_nil? false
      public? true
    end

    attribute :meal_type, :atom do
      constraints one_of: [:breakfast, :lunch, :dinner, :snack]
      allow_nil? false
      public? true
    end

    attribute :servings, :integer do
      default 4
      public? true
    end

    attribute :template_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :recipe_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :account_id, :uuid do
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :account, GroceryPlanner.Accounts.Account do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :template, GroceryPlanner.MealPlanning.MealPlanTemplate do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :recipe, GroceryPlanner.Recipes.Recipe do
      allow_nil? false
      attribute_writable? true
    end
  end
end
