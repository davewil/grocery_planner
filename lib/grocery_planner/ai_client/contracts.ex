defmodule GroceryPlanner.AiClient.Contracts do
  @moduledoc """
  Contract definitions for AI service API responses.
  Used for response validation in tests and runtime verification.
  """

  defmodule CategorizationResponse do
    @moduledoc """
    Validates the payload returned by the /api/v1/categorize endpoint.
    """
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :category, :string
      field :confidence, :float
      field :confidence_level, :string
      field :all_scores, :map
      field :processing_time_ms, :float
    end

    def validate(data) when is_map(data) do
      %__MODULE__{}
      |> cast(data, [:category, :confidence, :confidence_level, :all_scores, :processing_time_ms])
      |> validate_required([:category, :confidence])
      |> validate_number(:confidence, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
      |> validate_inclusion(:confidence_level, ["high", "medium", "low"])
      |> apply_action(:validate)
    end
  end

  defmodule ExtractionResponse do
    @moduledoc """
    Validates the payload returned by the /api/v1/extract-receipt endpoint.
    """
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :merchant, :string
      field :date, :string
      field :total, :float
      field :items, {:array, :map}
    end

    def validate(data) when is_map(data) do
      %__MODULE__{}
      |> cast(data, [:merchant, :date, :total, :items])
      |> validate_required([:items])
      |> validate_items()
      |> apply_action(:validate)
    end

    defp validate_items(changeset) do
      case get_field(changeset, :items) do
        nil ->
          changeset

        items when is_list(items) ->
          if Enum.all?(items, &valid_item?/1) do
            changeset
          else
            add_error(changeset, :items, "all items must have a name field")
          end

        _ ->
          add_error(changeset, :items, "must be a list")
      end
    end

    defp valid_item?(%{"name" => name}) when is_binary(name), do: true
    defp valid_item?(_), do: false
  end

  defmodule HealthResponse do
    @moduledoc """
    Validates the response from /health/ready endpoint.
    """
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :status, :string
      field :checks, :map
      field :version, :string
    end

    def validate(data) when is_map(data) do
      %__MODULE__{}
      |> cast(data, [:status, :checks, :version])
      |> validate_required([:status, :version])
      |> validate_inclusion(:status, ["ok", "degraded", "error"])
      |> apply_action(:validate)
    end
  end
end
