defmodule GroceryPlanner.Shopping.ShoppingListItem do
  use Ash.Resource,
    domain: GroceryPlanner.Shopping,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "shopping_list_items"
    repo GroceryPlanner.Repo
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
