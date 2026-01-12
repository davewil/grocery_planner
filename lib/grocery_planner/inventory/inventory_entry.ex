defmodule GroceryPlanner.Inventory.InventoryEntry do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    table "inventory_entries"
    repo GroceryPlanner.Repo
  end

  json_api do
    type "inventory_entry"

    routes do
      base("/inventory_entries")
      get(:read)
      index :read
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  code_interface do
    define :create_inventory_entry, action: :create
    define :read
    define :list_inventory_entries_filtered, action: :list_filtered
    define :get_inventory_entry, action: :read, get_by: [:id]
    define :update_inventory_entry, action: :update
    define :destroy_inventory_entry, action: :destroy
  end

  actions do
    defaults [:read, :destroy]

    read :list_filtered do
      argument :status, :atom, default: :available
      argument :expiration_filter, :atom

      prepare build(load: [:grocery_item, :storage_location, :days_until_expiry, :is_expired])

      filter expr(status == ^arg(:status))

      filter expr(
               if is_nil(^arg(:expiration_filter)) do
                 true
               else
                 if ^arg(:expiration_filter) == :expired do
                   is_expired == true
                 else
                   if ^arg(:expiration_filter) == :today do
                     not is_nil(use_by_date) and fragment("DATE(?) = CURRENT_DATE", use_by_date)
                   else
                     if ^arg(:expiration_filter) == :tomorrow do
                       not is_nil(use_by_date) and
                         fragment("DATE(?) = CURRENT_DATE + INTERVAL '1 day'", use_by_date)
                     else
                       # this_week
                       not is_nil(use_by_date) and
                         fragment(
                           "DATE(?) BETWEEN CURRENT_DATE + INTERVAL '2 days' AND CURRENT_DATE + INTERVAL '3 days'",
                           use_by_date
                         )
                     end
                   end
                 end
               end
             )
    end

    create :create do
      accept [
        :quantity,
        :unit,
        :purchase_price,
        :purchase_date,
        :use_by_date,
        :notes,
        :status,
        :storage_location_id,
        :grocery_item_id
      ]

      argument :account_id, :uuid, allow_nil?: false

      change set_attribute(:account_id, arg(:account_id))
    end

    update :update do
      accept [
        :quantity,
        :unit,
        :purchase_price,
        :purchase_date,
        :use_by_date,
        :notes,
        :status,
        :storage_location_id
      ]

      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if relates_to_actor_via([:account, :memberships, :user])
    end
  end

  multitenancy do
    strategy :attribute
    attribute :account_id
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity, :decimal do
      allow_nil? false
      public? true
    end

    attribute :unit, :string do
      public? true
    end

    attribute :purchase_price, AshMoney.Types.Money do
      public? true
    end

    attribute :purchase_date, :date do
      public? true
    end

    attribute :use_by_date, :date do
      public? true
    end

    attribute :notes, :string do
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:available, :reserved, :expired, :consumed]
      default :available
      public? true
    end

    attribute :account_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :grocery_item_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :storage_location_id, :uuid do
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

    belongs_to :grocery_item, GroceryPlanner.Inventory.GroceryItem do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :storage_location, GroceryPlanner.Inventory.StorageLocation do
      attribute_writable? true
    end
  end

  calculations do
    calculate :days_until_expiry,
              :integer,
              expr(
                fragment(
                  "CASE WHEN ? IS NULL THEN NULL ELSE ? - CURRENT_DATE END",
                  use_by_date,
                  use_by_date
                )
              )

    calculate :is_expiring_soon,
              :boolean,
              expr(
                fragment(
                  "? IS NOT NULL AND ? <= CURRENT_DATE + INTERVAL '7 days'",
                  use_by_date,
                  use_by_date
                )
              )

    calculate :is_expired,
              :boolean,
              expr(
                fragment(
                  "? IS NOT NULL AND ? < CURRENT_DATE",
                  use_by_date,
                  use_by_date
                )
              )
  end
end
