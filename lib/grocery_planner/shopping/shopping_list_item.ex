defmodule GroceryPlanner.Shopping.ShoppingListItem do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.Shopping,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    table "shopping_list_items"
    repo GroceryPlanner.Repo
  end

  json_api do
    type "shopping_list_item"

    routes do
      base("/shopping_lists/:shopping_list_id/items")

      index :read do
        derive_filter?(true)
      end

      get(:read)
      post(:create_from_api)
      patch(:update)
      delete(:destroy)

      patch(:check, route: "/:id/check")
      patch(:uncheck, route: "/:id/uncheck")
      patch(:toggle_check, route: "/:id/toggle")
      patch(:add_to_inventory, route: "/:id/add_to_inventory")
    end
  end

  code_interface do
    domain GroceryPlanner.Shopping

    define :create
    define :read
    define :update
    define :destroy
    define :check
    define :uncheck
    define :toggle_check
    define :add_to_inventory
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :grocery_item_id,
        :name,
        :quantity,
        :unit,
        :price,
        :notes,
        :checked
      ]

      argument :shopping_list_id, :uuid, allow_nil?: false
      argument :account_id, :uuid, allow_nil?: false

      change manage_relationship(:shopping_list_id, :shopping_list, type: :append)
      change manage_relationship(:account_id, :account, type: :append)
    end

    create :create_from_api do
      accept [
        :grocery_item_id,
        :name,
        :quantity,
        :unit,
        :price,
        :notes,
        :checked
      ]

      argument :shopping_list_id, :uuid, allow_nil?: false

      change fn changeset, context ->
        shopping_list_id = Ash.Changeset.get_argument(changeset, :shopping_list_id)
        tenant = context.tenant

        opts = [authorize?: false]
        opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

        case GroceryPlanner.Shopping.get_shopping_list(shopping_list_id, opts) do
          {:ok, shopping_list} ->
            changeset
            |> Ash.Changeset.manage_relationship(:shopping_list, shopping_list, type: :append)
            |> Ash.Changeset.change_attribute(:account_id, shopping_list.account_id)

          {:error, _} ->
            Ash.Changeset.add_error(changeset, field: :shopping_list_id, message: "not found")
        end
      end
    end

    update :update do
      accept [
        :grocery_item_id,
        :name,
        :quantity,
        :unit,
        :price,
        :notes,
        :checked
      ]

      require_atomic? false
    end

    update :check do
      accept []

      change set_attribute(:checked, true)
      change set_attribute(:checked_at, &DateTime.utc_now/0)

      require_atomic? false
    end

    update :uncheck do
      accept []

      change set_attribute(:checked, false)
      change set_attribute(:checked_at, nil)

      require_atomic? false
    end

    update :toggle_check do
      accept []

      change fn changeset, _context ->
        current_checked = Ash.Changeset.get_attribute(changeset, :checked) || false

        changeset
        |> Ash.Changeset.change_attribute(:checked, !current_checked)
        |> Ash.Changeset.change_attribute(
          :checked_at,
          if(!current_checked, do: DateTime.utc_now(), else: nil)
        )
      end

      require_atomic? false
    end

    update :add_to_inventory do
      accept []

      argument :storage_location_id, :uuid
      argument :purchase_date, :date
      argument :use_by_date, :date

      change fn changeset, context ->
        item = changeset.data

        # Get grocery_item_id from the shopping list item
        grocery_item_id = item.grocery_item_id

        if is_nil(grocery_item_id) do
          Ash.Changeset.add_error(changeset,
            field: :grocery_item_id,
            message: "Cannot add to inventory: shopping list item is not linked to a grocery item"
          )
        else
          # Extract optional arguments
          storage_location_id = Ash.Changeset.get_argument(changeset, :storage_location_id)
          purchase_date = Ash.Changeset.get_argument(changeset, :purchase_date)
          use_by_date = Ash.Changeset.get_argument(changeset, :use_by_date)

          # Create inventory entry attributes
          inventory_attrs = %{
            quantity: item.quantity,
            unit: item.unit,
            purchase_price: item.price,
            purchase_date: purchase_date,
            use_by_date: use_by_date,
            storage_location_id: storage_location_id
          }

          # Create the inventory entry using the domain code interface
          case GroceryPlanner.Inventory.create_inventory_entry(
                 item.account_id,
                 grocery_item_id,
                 inventory_attrs,
                 actor: context.actor,
                 tenant: context.tenant
               ) do
            {:ok, _inventory_entry} ->
              changeset

            {:error, error} ->
              Ash.Changeset.add_error(changeset,
                field: :base,
                message: "Failed to create inventory entry: #{inspect(error)}"
              )
          end
        end
      end

      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type([:update, :destroy]) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action(:add_to_inventory) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end
  end

  multitenancy do
    strategy :attribute
    attribute :account_id
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :quantity, :decimal do
      default Decimal.new("1")
      public? true
    end

    attribute :unit, :string do
      public? true
    end

    attribute :checked, :boolean do
      default false
      public? true
    end

    attribute :checked_at, :utc_datetime do
      public? true
    end

    attribute :price, AshMoney.Types.Money do
      public? true
    end

    attribute :notes, :string do
      public? true
    end

    attribute :shopping_list_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :grocery_item_id, :uuid do
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
    belongs_to :shopping_list, GroceryPlanner.Shopping.ShoppingList do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :grocery_item, GroceryPlanner.Inventory.GroceryItem do
      attribute_writable? true
    end

    belongs_to :account, GroceryPlanner.Accounts.Account do
      allow_nil? false
      attribute_writable? true
    end
  end

  calculations do
    calculate :display_name, :string do
      calculation expr(
                    if is_nil(grocery_item_id) do
                      name
                    else
                      grocery_item.name
                    end
                  )
    end
  end
end
