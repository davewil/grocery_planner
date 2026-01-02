defmodule GroceryPlanner.AI.Categorizer do
  @moduledoc """
  Provides AI-based categorization for grocery items.
  """

  # In a real production environment, you would:
  # 1. Download the model weights during the build process (Dockerfile).
  # 2. Point Bumblebee to the local path using {:local, "/path/to/model"}.
  #
  # For this development spike, Bumblebee caches the model in `~/.cache/bumblebee`
  # automatically. So subsequent calls to `load_model` are fast and do not re-download.
  
  def serving do
    # Using a smaller model that works well for zero-shot
    repo = {:hf, "cross-encoder/nli-distilroberta-base"}
    
    {:ok, model_info} = Bumblebee.load_model(repo)
    {:ok, tokenizer} = Bumblebee.load_tokenizer(repo)

    labels = ["Produce", "Dairy", "Meat", "Bakery", "Frozen", "Pantry"]
    
    # IMPORTANT: We are NOT using EXLA here anymore because it seems to be causing
    # timeouts or hanging in this specific environment, possibly due to 
    # resource constraints or compilation issues.
    # We rely on the default BinaryBackend (CPU) which is slower but more reliable for a spike.
    Bumblebee.Text.zero_shot_classification(
      model_info, 
      tokenizer, 
      labels, 
      compile: [batch_size: 1, sequence_length: 100],
      defn_options: [] # Explicitly empty options to avoid EXLA if it was default
    )
  end

  def predict(text, _labels) do
    # When using a serving with fixed labels (which is what we built above),
    # the run function just takes the text.
    # The serving itself already knows the labels.
    Nx.Serving.batched_run(__MODULE__, text)
  end
end
