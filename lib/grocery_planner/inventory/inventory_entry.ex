defmodule GroceryPlanner.Inventory.InventoryEntry do
  @moduledoc false
  use Ash.Resource,
    domain: GroceryPlanner.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource],
    primary_read_warning?: false

  postgres do
    table "inventory_entries"
    repo GroceryPlanner.Repo
  end

  json_api do
    type "inventory_entry"

    routes do
      base("/grocery_items/:grocery_item_id/inventory_entries")

      index :list_by_grocery_item
      get(:read)
      post(:create_from_api)
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
    defaults []

    read :read do
      primary? true
      filter expr(is_nil(deleted_at))
    end

    destroy :destroy do
      primary? true
      soft? true
      change set_attribute(:deleted_at, &DateTime.utc_now/0)
    end

    read :sync do
      argument :since, :utc_datetime_usec
      argument :limit, :integer

      filter expr(
               if is_nil(^arg(:since)) do
                 true
               else
                 updated_at >= ^arg(:since) or
                   (not is_nil(deleted_at) and deleted_at >= ^arg(:since))
               end
             )

      prepare build(sort: [updated_at: :asc])

      prepare fn query, _context ->
        case Ash.Query.get_argument(query, :limit) do
          nil -> query
          limit -> Ash.Query.limit(query, limit)
        end
      end
    end

    read :list_by_grocery_item do
      argument :grocery_item_id, :uuid, allow_nil?: false

      filter expr(is_nil(deleted_at))
      filter expr(grocery_item_id == ^arg(:grocery_item_id))
    end

    read :list_filtered do
      argument :status, :atom, default: :available
      argument :expiration_filter, :atom

      prepare build(load: [:grocery_item, :storage_location, :days_until_expiry, :is_expired])

      filter expr(is_nil(deleted_at))
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

      validate present(:quantity)

      change set_attribute(:account_id, arg(:account_id))
    end

    create :create_from_api do
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

      argument :grocery_item_id, :uuid, allow_nil?: false
      argument :shopping_list_item_id, :uuid, allow_nil?: true

      validate fn changeset, _context ->
        shopping_list_item_id = Ash.Changeset.get_argument(changeset, :shopping_list_item_id)
        quantity = changeset.attributes[:quantity]

        if is_nil(shopping_list_item_id) and is_nil(quantity) do
          {:error,
           field: :quantity, message: "is required when shopping_list_item_id is not provided"}
        else
          :ok
        end
      end

      change fn changeset, context ->
        grocery_item_id = Ash.Changeset.get_argument(changeset, :grocery_item_id)
        shopping_list_item_id = Ash.Changeset.get_argument(changeset, :shopping_list_item_id)
        tenant = context.tenant

        opts = [authorize?: false]
        opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

        case GroceryPlanner.Inventory.get_grocery_item(grocery_item_id, opts) do
          {:ok, grocery_item} ->
            changeset =
              changeset
              |> Ash.Changeset.manage_relationship(:grocery_item, grocery_item, type: :append)
              |> Ash.Changeset.change_attribute(:account_id, grocery_item.account_id)

            # If shopping_list_item_id is provided, derive values from it
            if shopping_list_item_id do
              case GroceryPlanner.Shopping.get_shopping_list_item(shopping_list_item_id, opts) do
                {:ok, shopping_list_item} ->
                  # Validate that the shopping list item belongs to the same account
                  if shopping_list_item.account_id == grocery_item.account_id do
                    # Derive quantity, unit, price, and notes from shopping list item if not explicitly provided
                    # Check both the changeset arguments and attributes to see if they were provided
                    changeset =
                      if is_nil(changeset.attributes[:quantity]) do
                        Ash.Changeset.change_attribute(
                          changeset,
                          :quantity,
                          shopping_list_item.quantity
                        )
                      else
                        changeset
                      end

                    changeset =
                      if is_nil(changeset.attributes[:unit]) do
                        Ash.Changeset.change_attribute(changeset, :unit, shopping_list_item.unit)
                      else
                        changeset
                      end

                    changeset =
                      if is_nil(changeset.attributes[:purchase_price]) do
                        Ash.Changeset.change_attribute(
                          changeset,
                          :purchase_price,
                          shopping_list_item.price
                        )
                      else
                        changeset
                      end

                    changeset =
                      if is_nil(changeset.attributes[:notes]) do
                        Ash.Changeset.change_attribute(
                          changeset,
                          :notes,
                          shopping_list_item.notes
                        )
                      else
                        changeset
                      end

                    changeset
                  else
                    Ash.Changeset.add_error(changeset,
                      field: :shopping_list_item_id,
                      message: "shopping list item does not belong to the same account"
                    )
                  end

                {:error, _} ->
                  Ash.Changeset.add_error(changeset,
                    field: :shopping_list_item_id,
                    message: "not found"
                  )
              end
            else
              changeset
            end

          {:error, _} ->
            Ash.Changeset.add_error(changeset, field: :grocery_item_id, message: "not found")
        end
      end
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

    attribute :quantity, :decimal do
      allow_nil? true
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

    attribute :storage_location_id, :uuid do
      public? true
    end

    attribute :deleted_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :created_at, public?: true
    update_timestamp :updated_at, public?: true
  end

  relationships do
    belongs_to :account, GroceryPlanner.Accounts.Account do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :grocery_item, GroceryPlanner.Inventory.GroceryItem do
      allow_nil? false
      attribute_writable? true
      public? true
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
