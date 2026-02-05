defmodule GroceryPlanner.AiClient.Contracts do
  @moduledoc """
  Contract definitions for AI service API responses.

  Validates response shapes from the Python sidecar service to catch
  schema drift between services. Each contract uses Ecto embedded schemas
  with changesets for validation.

  ## Usage

      iex> data = %{"category" => "Produce", "confidence" => 0.95, ...}
      iex> Contracts.CategorizationResponse.validate(data)
      {:ok, %CategorizationResponse{}}

  These contracts mirror the Pydantic models in `python_service/schemas.py`.
  """

  defmodule BaseResponse do
    @moduledoc "Validates the envelope wrapper returned by most Python endpoints."
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :request_id, :string
      field :status, :string
      field :payload, :map
      field :error, :string
      field :metadata, :map
    end

    @doc "Validates a raw response map matches the BaseResponse envelope."
    def validate(data) when is_map(data) do
      %__MODULE__{}
      |> cast(normalize(data), [:request_id, :status, :payload, :error, :metadata])
      |> validate_required([:request_id, :status])
      |> validate_inclusion(:status, ["success", "error"])
      |> apply_action(:validate)
    end

    def validate(_), do: {:error, :not_a_map}

    defp normalize(data) do
      Map.new(data, fn {k, v} -> {to_string(k), v} end)
      |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)
    rescue
      _ -> data
    end
  end

  defmodule CategorizationResponse do
    @moduledoc "Validates the payload from `POST /api/v1/categorize`."
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

    @doc "Validates a categorization response payload."
    def validate(data) when is_map(data) do
      %__MODULE__{}
      |> cast(atomize(data), [
        :category,
        :confidence,
        :confidence_level,
        :all_scores,
        :processing_time_ms
      ])
      |> validate_required([:category, :confidence])
      |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
      |> validate_inclusion(:confidence_level, ["high", "medium", "low"])
      |> apply_action(:validate)
    end

    def validate(_), do: {:error, :not_a_map}

    defp atomize(data), do: Map.new(data, fn {k, v} -> {to_atom(k), v} end)
    defp to_atom(k) when is_atom(k), do: k
    defp to_atom(k) when is_binary(k), do: String.to_existing_atom(k)
  end

  defmodule BatchPrediction do
    @moduledoc "A single prediction within a batch categorization response."
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :id, :string
      field :name, :string
      field :predicted_category, :string
      field :confidence, :float
      field :confidence_level, :string
    end

    def validate(data) when is_map(data) do
      %__MODULE__{}
      |> cast(atomize(data), [:id, :name, :predicted_category, :confidence, :confidence_level])
      |> validate_required([:id, :predicted_category, :confidence])
      |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
      |> validate_inclusion(:confidence_level, ["high", "medium", "low"])
      |> apply_action(:validate)
    end

    def validate(_), do: {:error, :not_a_map}

    defp atomize(data), do: Map.new(data, fn {k, v} -> {to_atom(k), v} end)
    defp to_atom(k) when is_atom(k), do: k
    defp to_atom(k) when is_binary(k), do: String.to_existing_atom(k)
  end

  defmodule BatchCategorizationResponse do
    @moduledoc "Validates the payload from `POST /api/v1/categorize-batch`."

    @doc "Validates a batch categorization response payload."
    def validate(%{"predictions" => predictions, "processing_time_ms" => time})
        when is_list(predictions) and is_number(time) do
      results = Enum.map(predictions, &BatchPrediction.validate/1)

      case Enum.find(results, &match?({:error, _}, &1)) do
        nil ->
          {:ok, %{predictions: Enum.map(results, fn {:ok, r} -> r end), processing_time_ms: time}}

        error ->
          error
      end
    end

    def validate(%{predictions: _, processing_time_ms: _} = data) do
      data
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> validate()
    end

    def validate(_), do: {:error, :invalid_batch_categorization_response}
  end

  defmodule ReceiptLineItem do
    @moduledoc "A single line item extracted from a receipt."
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :raw_text, :string
      field :parsed_name, :string
      field :quantity, :float
      field :unit, :string
      field :confidence, :float
    end

    def validate(data) when is_map(data) do
      %__MODULE__{}
      |> cast(atomize(data), [:raw_text, :parsed_name, :quantity, :unit, :confidence])
      |> validate_required([:raw_text, :confidence])
      |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
      |> apply_action(:validate)
    end

    def validate(_), do: {:error, :not_a_map}

    defp atomize(data), do: Map.new(data, fn {k, v} -> {to_atom(k), v} end)
    defp to_atom(k) when is_atom(k), do: k
    defp to_atom(k) when is_binary(k), do: String.to_existing_atom(k)
  end

  defmodule ReceiptExtractionResponse do
    @moduledoc "Validates the payload from `POST /api/v1/extract-receipt`."

    @doc "Validates a receipt extraction response payload."
    def validate(data) when is_map(data) do
      with {:ok, extraction} <- get_extraction(data),
           {:ok, line_items} <- validate_line_items(extraction) do
        {:ok,
         %{
           merchant:
             get_in(extraction, ["merchant", "name"]) || get_in(extraction, [:merchant, :name]),
           date: get_in(extraction, ["date", "value"]) || get_in(extraction, [:date, :value]),
           total:
             get_in(extraction, ["total", "amount"]) || get_in(extraction, [:total, :amount]),
           line_items: line_items,
           overall_confidence: extraction["overall_confidence"] || extraction[:overall_confidence]
         }}
      end
    end

    def validate(_), do: {:error, :not_a_map}

    defp get_extraction(data) do
      case data["extraction"] || data[:extraction] do
        nil -> {:error, :missing_extraction}
        ext when is_map(ext) -> {:ok, ext}
        _ -> {:error, :invalid_extraction}
      end
    end

    defp validate_line_items(extraction) do
      items = extraction["line_items"] || extraction[:line_items] || []

      results = Enum.map(items, &ReceiptLineItem.validate/1)

      case Enum.find(results, &match?({:error, _}, &1)) do
        nil -> {:ok, Enum.map(results, fn {:ok, r} -> r end)}
        error -> error
      end
    end
  end

  defmodule EmbeddingEntry do
    @moduledoc "A single embedding vector entry."
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :id, :string
      field :vector, {:array, :float}
    end

    def validate(data) when is_map(data) do
      %__MODULE__{}
      |> cast(atomize(data), [:id, :vector])
      |> validate_required([:id, :vector])
      |> apply_action(:validate)
    end

    def validate(_), do: {:error, :not_a_map}

    defp atomize(data), do: Map.new(data, fn {k, v} -> {to_atom(k), v} end)
    defp to_atom(k) when is_atom(k), do: k
    defp to_atom(k) when is_binary(k), do: String.to_existing_atom(k)
  end

  defmodule EmbeddingResponse do
    @moduledoc "Validates the response from `POST /api/v1/embed`."

    @doc "Validates an embedding response."
    def validate(data) when is_map(data) do
      with :ok <- require_field(data, "model"),
           :ok <- require_field(data, "dimension"),
           {:ok, embeddings} <- validate_embeddings(data) do
        {:ok,
         %{
           model: data["model"] || data[:model],
           dimension: data["dimension"] || data[:dimension],
           embeddings: embeddings
         }}
      end
    end

    def validate(_), do: {:error, :not_a_map}

    defp require_field(data, field) do
      if Map.has_key?(data, field) || Map.has_key?(data, String.to_existing_atom(field)) do
        :ok
      else
        {:error, {:missing_field, field}}
      end
    rescue
      _ -> {:error, {:missing_field, field}}
    end

    defp validate_embeddings(data) do
      items = data["embeddings"] || data[:embeddings] || []

      results = Enum.map(items, &EmbeddingEntry.validate/1)

      case Enum.find(results, &match?({:error, _}, &1)) do
        nil -> {:ok, Enum.map(results, fn {:ok, r} -> r end)}
        error -> error
      end
    end
  end

  defmodule HealthCheckResponse do
    @moduledoc "Validates the response from `GET /health/ready`."
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :status, :string
      field :checks, :map
      field :version, :string
    end

    @doc "Validates a health check response."
    def validate(data) when is_map(data) do
      %__MODULE__{}
      |> cast(atomize(data), [:status, :checks, :version])
      |> validate_required([:status])
      |> validate_inclusion(:status, ["ok", "degraded", "error"])
      |> apply_action(:validate)
    end

    def validate(_), do: {:error, :not_a_map}

    defp atomize(data), do: Map.new(data, fn {k, v} -> {to_atom(k), v} end)
    defp to_atom(k) when is_atom(k), do: k
    defp to_atom(k) when is_binary(k), do: String.to_existing_atom(k)
  end

  defmodule MealPlanEntry do
    @moduledoc "A single meal in an optimization plan."
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :date, :string
      field :day_index, :integer
      field :meal_type, :string
      field :recipe_id, :string
      field :recipe_name, :string
    end

    def validate(data) when is_map(data) do
      %__MODULE__{}
      |> cast(atomize(data), [:date, :day_index, :meal_type, :recipe_id, :recipe_name])
      |> validate_required([:date, :recipe_id, :recipe_name])
      |> apply_action(:validate)
    end

    def validate(_), do: {:error, :not_a_map}

    defp atomize(data), do: Map.new(data, fn {k, v} -> {to_atom(k), v} end)
    defp to_atom(k) when is_atom(k), do: k
    defp to_atom(k) when is_binary(k), do: String.to_existing_atom(k)
  end

  defmodule MealOptimizationResponse do
    @moduledoc "Validates the payload from `POST /api/v1/optimize`."

    @valid_statuses ["optimal", "no_solution", "timeout", "infeasible"]

    @doc "Validates a meal optimization response payload."
    def validate(data) when is_map(data) do
      status = data["status"] || data[:status]

      cond do
        is_nil(status) ->
          {:error, :missing_status}

        status not in @valid_statuses ->
          {:error, {:invalid_status, status}}

        status == "no_solution" ->
          {:ok,
           %{status: status, meal_plan: [], shopping_list: [], metrics: nil, explanation: []}}

        true ->
          validate_full(data, status)
      end
    end

    def validate(_), do: {:error, :not_a_map}

    defp validate_full(data, status) do
      meal_plan = data["meal_plan"] || data[:meal_plan] || []

      results = Enum.map(meal_plan, &MealPlanEntry.validate/1)

      case Enum.find(results, &match?({:error, _}, &1)) do
        nil ->
          {:ok,
           %{
             status: status,
             meal_plan: Enum.map(results, fn {:ok, r} -> r end),
             shopping_list: data["shopping_list"] || data[:shopping_list] || [],
             metrics: data["metrics"] || data[:metrics],
             explanation: data["explanation"] || data[:explanation] || []
           }}

        error ->
          error
      end
    end
  end

  defmodule QuickSuggestionEntry do
    @moduledoc "A single recipe suggestion."
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :recipe_id, :string
      field :recipe_name, :string
      field :score, :float
      field :reason, :string
    end

    def validate(data) when is_map(data) do
      %__MODULE__{}
      |> cast(atomize(data), [:recipe_id, :recipe_name, :score, :reason])
      |> validate_required([:recipe_id, :recipe_name, :score])
      |> validate_number(:score, greater_than_or_equal_to: 0.0)
      |> apply_action(:validate)
    end

    def validate(_), do: {:error, :not_a_map}

    defp atomize(data), do: Map.new(data, fn {k, v} -> {to_atom(k), v} end)
    defp to_atom(k) when is_atom(k), do: k
    defp to_atom(k) when is_binary(k), do: String.to_existing_atom(k)
  end

  defmodule QuickSuggestionResponse do
    @moduledoc "Validates the payload from `POST /api/v1/suggest`."

    @doc "Validates a quick suggestion response payload."
    def validate(data) when is_map(data) do
      suggestions = data["suggestions"] || data[:suggestions]

      case suggestions do
        nil ->
          {:error, :missing_suggestions}

        items when is_list(items) ->
          results = Enum.map(items, &QuickSuggestionEntry.validate/1)

          case Enum.find(results, &match?({:error, _}, &1)) do
            nil -> {:ok, %{suggestions: Enum.map(results, fn {:ok, r} -> r end)}}
            error -> error
          end

        _ ->
          {:error, :suggestions_not_a_list}
      end
    end

    def validate(_), do: {:error, :not_a_map}
  end
end
