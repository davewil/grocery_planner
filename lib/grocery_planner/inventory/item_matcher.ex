defmodule GroceryPlanner.Inventory.ItemMatcher do
  @moduledoc """
  Matches extracted receipt item names to existing grocery catalog items.
  Uses multiple strategies in order of preference: exact, normalized, fuzzy.
  """

  require Logger

  alias GroceryPlanner.Inventory

  @type match_result :: %{
          item: term(),
          confidence: float(),
          strategy: :exact | :normalized | :fuzzy
        }

  @doc """
  Finds the best matching GroceryItem for an extracted name.
  Tries strategies in order: exact -> normalized -> fuzzy.
  Returns {:ok, match_result} or {:no_match, nil}.
  """
  @spec find_best_match(String.t(), String.t(), keyword()) ::
          {:ok, match_result()} | {:no_match, nil}
  def find_best_match(extracted_name, account_id, opts \\ []) do
    actor = opts[:actor]

    strategies = [
      &exact_match/3,
      &normalized_match/3,
      &fuzzy_match/3
    ]

    Enum.find_value(strategies, {:no_match, nil}, fn strategy ->
      case strategy.(extracted_name, account_id, actor) do
        {:ok, match} when match.confidence > 0.7 -> {:ok, match}
        _ -> nil
      end
    end)
  end

  @doc """
  Matches all items in a receipt to the grocery catalog.
  Returns a list of {receipt_item, match_result} tuples.
  """
  @spec match_receipt_items(list(map()), String.t(), keyword()) ::
          list({map(), {:ok, match_result()} | {:no_match, nil}})
  def match_receipt_items(receipt_items, account_id, opts \\ []) do
    Enum.map(receipt_items, fn item ->
      name = item.final_name || item.raw_name
      match = find_best_match(name, account_id, opts)
      {item, match}
    end)
  end

  @doc """
  Normalizes a receipt item name by expanding common abbreviations
  and cleaning up OCR artifacts.
  """
  @spec normalize_name(String.t()) :: String.t()
  def normalize_name(name) do
    name
    |> String.downcase()
    |> String.trim()
    |> expand_abbreviations()
    |> String.replace(~r/\s+/, " ")
  end

  # Private functions

  # Strategy 1: Exact case-insensitive match
  defp exact_match(name, account_id, _actor) do
    case Inventory.get_item_by_name(String.downcase(name),
           authorize?: false,
           tenant: account_id
         ) do
      {:ok, item} when not is_nil(item) ->
        {:ok, %{item: item, confidence: 1.0, strategy: :exact}}

      _ ->
        {:no_match, nil}
    end
  rescue
    _ -> {:no_match, nil}
  end

  # Strategy 2: Normalized match (expand common abbreviations)
  defp normalized_match(name, account_id, _actor) do
    normalized = normalize_name(name)

    if normalized != String.downcase(name) do
      case Inventory.get_item_by_name(normalized,
             authorize?: false,
             tenant: account_id
           ) do
        {:ok, item} when not is_nil(item) ->
          {:ok, %{item: item, confidence: 0.9, strategy: :normalized}}

        _ ->
          {:no_match, nil}
      end
    else
      {:no_match, nil}
    end
  rescue
    _ -> {:no_match, nil}
  end

  # Strategy 3: Fuzzy string matching using Jaro distance
  defp fuzzy_match(name, account_id, _actor) do
    case Inventory.list_grocery_items(authorize?: false, tenant: account_id) do
      {:ok, items} when items != [] ->
        best =
          items
          |> Enum.map(fn item ->
            score = String.jaro_distance(String.downcase(name), String.downcase(item.name))
            {item, score}
          end)
          |> Enum.max_by(fn {_, score} -> score end)

        case best do
          {item, score} when score > 0.8 ->
            {:ok, %{item: item, confidence: score, strategy: :fuzzy}}

          _ ->
            {:no_match, nil}
        end

      _ ->
        {:no_match, nil}
    end
  rescue
    _ -> {:no_match, nil}
  end

  # Common grocery receipt abbreviations
  defp expand_abbreviations(name) do
    abbreviations = %{
      "org" => "organic",
      "whl" => "whole",
      "frz" => "frozen",
      "chkn" => "chicken",
      "brst" => "breast",
      "bnls" => "boneless",
      "sknls" => "skinless",
      "grn" => "green",
      "red" => "red",
      "ylw" => "yellow",
      "lg" => "large",
      "sm" => "small",
      "med" => "medium",
      "ff" => "fat free",
      "lf" => "low fat",
      "rf" => "reduced fat",
      "ww" => "whole wheat",
      "gf" => "gluten free",
      "choc" => "chocolate",
      "van" => "vanilla",
      "strw" => "strawberry",
      "blubrry" => "blueberry",
      "bby" => "baby",
      "veg" => "vegetable",
      "tom" => "tomato",
      "mush" => "mushroom",
      "pep" => "pepper",
      "ched" => "cheddar",
      "mozz" => "mozzarella",
      "parm" => "parmesan",
      "crm" => "cream",
      "btl" => "bottle",
      "cn" => "can",
      "pk" => "pack",
      "bg" => "bag",
      "bx" => "box",
      "ct" => "count",
      "oz" => "ounce",
      "lb" => "pound",
      "gl" => "gallon",
      "qt" => "quart",
      "pt" => "pint",
      "dz" => "dozen"
    }

    words = String.split(name)

    words
    |> Enum.map(fn word ->
      Map.get(abbreviations, word, word)
    end)
    |> Enum.join(" ")
  end
end
