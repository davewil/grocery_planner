defmodule GroceryPlanner.Inventory.ReceiptItem do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :name, :string do
      public? true
    end

    attribute :quantity, :decimal do
      public? true
    end

    attribute :unit, :string do
      public? true
    end

    attribute :price, AshMoney.Types.Money do
      public? true
    end

    attribute :confidence, :float do
      public? true
    end
  end
end
