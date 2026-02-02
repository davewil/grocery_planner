# AI-005: Chat Assistant with Tools

## Overview

**Feature:** Conversational AI assistant with tool-calling capabilities for meal planning and inventory management
**Priority:** Medium
**Epic:** AST-01 (AI Assistant)
**Estimated Effort:** 10-14 days

## Problem Statement

Users want a natural, conversational way to interact with their grocery and meal planning system. They want to ask questions like "What's expiring soon?" or "What can I make for dinner?" without navigating through multiple screens.

**Current Pain Points:**
- Multiple clicks required to check expiration status
- Finding recipes requires manual filtering
- Creating shopping lists is a multi-step process
- No unified interface for common queries

## User Stories

### US-001: Ask about expiring items
**As a** user
**I want** to ask "What's expiring soon?"
**So that** I get a quick summary without navigating to inventory

**Acceptance Criteria:**
- [ ] Natural language understanding of expiration queries
- [ ] Returns actual items from database (no hallucinations)
- [ ] Shows days until expiry for each item
- [ ] Suggests actions ("Would you like recipe suggestions?")

### US-002: Get recipe suggestions
**As a** user
**I want** to ask "What can I make with chicken and rice?"
**So that** I get relevant recipe recommendations

**Acceptance Criteria:**
- [ ] Understands ingredient-based queries
- [ ] Returns recipes from user's collection
- [ ] Shows ingredient availability status
- [ ] Indicates missing ingredients

### US-003: Create shopping list via chat
**As a** user
**I want** to say "Create a shopping list for this week's meals"
**So that** I can quickly prepare for shopping

**Acceptance Criteria:**
- [ ] Understands shopping list creation intent
- [ ] Analyzes current meal plan
- [ ] Shows draft list before confirming
- [ ] User must explicitly confirm before creation

### US-004: Add meals to plan
**As a** user
**I want** to say "Add pasta carbonara to Tuesday's dinner"
**So that** I can plan meals conversationally

**Acceptance Criteria:**
- [ ] Understands meal planning commands
- [ ] Finds matching recipe in collection
- [ ] Shows confirmation before adding
- [ ] Creates meal plan entry on confirmation

### US-005: General cooking questions
**As a** user
**I want** to ask cooking-related questions
**So that** I get helpful guidance

**Acceptance Criteria:**
- [ ] Answers general cooking questions
- [ ] References user's recipes when relevant
- [ ] Provides helpful tips and substitutions
- [ ] Clearly distinguishes knowledge vs user data

## Technical Specification

### Architecture

```
┌─────────────────┐                    ┌──────────────────┐
│  Elixir/Phoenix │                    │  LLM Provider    │
│   (LiveView)    │                    │  (Claude API)    │
└────────┬────────┘                    └────────┬─────────┘
         │                                      │
         │  1. User message                     │
         ▼                                      │
┌─────────────────┐     2. LLM call    ┌───────┴──────────┐
│  Chat Context   │───────────────────►│  Tool Execution  │
│  Manager        │                    │  (Elixir)        │
└────────┬────────┘◄───────────────────└──────────────────┘
         │           3. Tool results
         │
         ▼
┌─────────────────┐
│   PostgreSQL    │
│   (Data + Chat) │
└─────────────────┘
```

### Tool Definitions

The assistant has access to these tools that query/modify the GroceryPlanner database:

#### Tool: get_expiring_items

```json
{
  "name": "get_expiring_items",
  "description": "Get a list of inventory items expiring within the specified number of days",
  "parameters": {
    "type": "object",
    "properties": {
      "days": {
        "type": "integer",
        "description": "Number of days to look ahead (default: 7)",
        "default": 7
      },
      "limit": {
        "type": "integer",
        "description": "Maximum number of items to return",
        "default": 10
      }
    }
  }
}
```

#### Tool: search_recipes

```json
{
  "name": "search_recipes",
  "description": "Search for recipes by name, ingredients, or description",
  "parameters": {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "Search query (recipe name or description)"
      },
      "ingredients": {
        "type": "array",
        "items": {"type": "string"},
        "description": "List of ingredients to search for"
      },
      "max_time": {
        "type": "integer",
        "description": "Maximum total cooking time in minutes"
      },
      "difficulty": {
        "type": "string",
        "enum": ["easy", "medium", "hard"],
        "description": "Difficulty level filter"
      }
    }
  }
}
```

#### Tool: get_recipe_details

```json
{
  "name": "get_recipe_details",
  "description": "Get detailed information about a specific recipe including ingredients and availability",
  "parameters": {
    "type": "object",
    "properties": {
      "recipe_id": {
        "type": "string",
        "description": "The UUID of the recipe"
      }
    },
    "required": ["recipe_id"]
  }
}
```

#### Tool: get_meal_plan

```json
{
  "name": "get_meal_plan",
  "description": "Get the meal plan for a date range",
  "parameters": {
    "type": "object",
    "properties": {
      "start_date": {
        "type": "string",
        "format": "date",
        "description": "Start date (YYYY-MM-DD)"
      },
      "end_date": {
        "type": "string",
        "format": "date",
        "description": "End date (YYYY-MM-DD)"
      }
    }
  }
}
```

#### Tool: draft_shopping_list

```json
{
  "name": "draft_shopping_list",
  "description": "Generate a draft shopping list based on meal plan and current inventory. Does NOT create the list - returns preview for user confirmation.",
  "parameters": {
    "type": "object",
    "properties": {
      "start_date": {
        "type": "string",
        "format": "date",
        "description": "Start date for meal plan analysis"
      },
      "end_date": {
        "type": "string",
        "format": "date",
        "description": "End date for meal plan analysis"
      }
    }
  }
}
```

#### Tool: propose_meal_plan_entry

```json
{
  "name": "propose_meal_plan_entry",
  "description": "Propose adding a recipe to the meal plan. Does NOT create - returns proposal for user confirmation.",
  "parameters": {
    "type": "object",
    "properties": {
      "recipe_id": {
        "type": "string",
        "description": "The UUID of the recipe to add"
      },
      "date": {
        "type": "string",
        "format": "date",
        "description": "The date to schedule"
      },
      "meal_type": {
        "type": "string",
        "enum": ["breakfast", "lunch", "dinner", "snack"],
        "description": "The meal type"
      },
      "servings": {
        "type": "integer",
        "description": "Number of servings",
        "default": 4
      }
    },
    "required": ["recipe_id", "date", "meal_type"]
  }
}
```

### Database Schema

```elixir
defmodule GroceryPlanner.Repo.Migrations.AddChatConversations do
  use Ecto.Migration

  def change do
    create table(:chat_conversations, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :account_id, references(:accounts, type: :uuid, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :title, :string
      add :status, :string, default: "active"  # active, archived

      timestamps(type: :utc_datetime)
    end

    create index(:chat_conversations, [:account_id])
    create index(:chat_conversations, [:user_id])

    create table(:chat_messages, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :conversation_id, references(:chat_conversations, type: :uuid, on_delete: :delete_all), null: false
      add :role, :string, null: false  # user, assistant, system, tool
      add :content, :text

      # For tool calls/results
      add :tool_calls, :jsonb  # Array of tool calls from assistant
      add :tool_call_id, :string  # For tool results
      add :tool_name, :string  # For tool results

      # Metadata
      add :model_version, :string
      add :tokens_used, :integer
      add :latency_ms, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:conversation_id])

    # Feedback for improvement
    create table(:chat_feedback, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :message_id, references(:chat_messages, type: :uuid, on_delete: :delete_all), null: false
      add :rating, :string  # positive, negative
      add :feedback_text, :text

      timestamps(type: :utc_datetime)
    end
  end
end
```

### Elixir Implementation

**Module:** `GroceryPlanner.AI.Assistant`

```elixir
defmodule GroceryPlanner.AI.Assistant do
  @moduledoc """
  Conversational AI assistant with tool-calling capabilities.
  """

  alias GroceryPlanner.AI.Assistant.{Conversation, ToolExecutor}

  @system_prompt """
  You are a helpful assistant for GroceryPlanner, a meal planning and grocery management app.

  Your capabilities:
  - Check what items are expiring soon
  - Search and recommend recipes
  - Help plan meals for the week
  - Draft shopping lists

  Important rules:
  1. ALWAYS use tools to get real data - never make up inventory items, recipes, or meal plans
  2. NEVER delete or modify data without explicit user confirmation
  3. When proposing changes (meal plans, shopping lists), show the user what will be created and ask for confirmation
  4. If you're unsure about something, ask for clarification
  5. Be concise but helpful

  When you call a tool, explain what you're doing. After getting results, summarize them clearly for the user.
  """

  @tools [
    %{name: "get_expiring_items", ...},
    %{name: "search_recipes", ...},
    %{name: "get_recipe_details", ...},
    %{name: "get_meal_plan", ...},
    %{name: "draft_shopping_list", ...},
    %{name: "propose_meal_plan_entry", ...}
  ]

  @doc """
  Sends a message and gets a response, potentially with tool calls.
  """
  @spec chat(Conversation.t(), String.t()) :: {:ok, response()} | {:error, term()}
  def chat(conversation, user_message) do
    # Add user message to history
    conversation = Conversation.add_message(conversation, :user, user_message)

    # Build messages for API
    messages = build_messages(conversation)

    # Call LLM with tools
    case call_llm(messages, @tools) do
      {:ok, %{tool_calls: tool_calls}} when tool_calls != [] ->
        # Execute tools and continue
        handle_tool_calls(conversation, tool_calls)

      {:ok, %{content: content}} ->
        # Final response
        conversation = Conversation.add_message(conversation, :assistant, content)
        {:ok, %{conversation: conversation, response: content}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_tool_calls(conversation, tool_calls) do
    # Add assistant message with tool calls
    conversation = Conversation.add_tool_calls(conversation, tool_calls)

    # Execute each tool
    tool_results = Enum.map(tool_calls, fn call ->
      result = ToolExecutor.execute(call.name, call.arguments, conversation.context)
      %{tool_call_id: call.id, name: call.name, result: result}
    end)

    # Add tool results to conversation
    conversation = Conversation.add_tool_results(conversation, tool_results)

    # Continue conversation with tool results
    messages = build_messages(conversation)

    case call_llm(messages, @tools) do
      {:ok, %{content: content}} ->
        conversation = Conversation.add_message(conversation, :assistant, content)
        {:ok, %{conversation: conversation, response: content, tool_results: tool_results}}

      {:ok, %{tool_calls: more_calls}} ->
        # Recursive tool calling (with depth limit)
        handle_tool_calls(conversation, more_calls)
    end
  end
end
```

**Tool Executor:**

```elixir
defmodule GroceryPlanner.AI.Assistant.ToolExecutor do
  @moduledoc """
  Executes tool calls against the GroceryPlanner database.
  All operations are read-only or return proposals (not actual changes).
  """

  alias GroceryPlanner.{Inventory, Recipes, MealPlanning, Shopping}

  def execute("get_expiring_items", args, context) do
    days = Map.get(args, "days", 7)
    limit = Map.get(args, "limit", 10)

    items = Inventory.get_expiring_items(context.account, days: days, limit: limit)

    %{
      items: Enum.map(items, fn item ->
        %{
          name: item.grocery_item.name,
          quantity: "#{item.quantity} #{item.unit}",
          days_until_expiry: item.days_until_expiry,
          storage_location: item.storage_location.name
        }
      end),
      total_count: length(items)
    }
  end

  def execute("search_recipes", args, context) do
    opts = [
      query: args["query"],
      ingredients: args["ingredients"],
      max_time: args["max_time"],
      difficulty: args["difficulty"]
    ] |> Enum.reject(fn {_, v} -> is_nil(v) end)

    recipes = Recipes.search_recipes(context.account, opts)

    %{
      recipes: Enum.map(recipes, fn recipe ->
        %{
          id: recipe.id,
          name: recipe.name,
          description: recipe.description,
          total_time: recipe.total_time_minutes,
          difficulty: recipe.difficulty,
          can_make: recipe.can_make,
          availability: "#{trunc(recipe.ingredient_availability)}%"
        }
      end),
      count: length(recipes)
    }
  end

  def execute("draft_shopping_list", args, context) do
    start_date = Date.from_iso8601!(args["start_date"])
    end_date = Date.from_iso8601!(args["end_date"])

    # Generate draft (does not save)
    draft = Shopping.generate_draft_from_meal_plans(
      context.account,
      start_date,
      end_date
    )

    %{
      status: "draft",
      message: "This is a preview. Say 'confirm' to create this shopping list.",
      items: Enum.map(draft.items, fn item ->
        %{
          name: item.name,
          quantity: "#{item.quantity} #{item.unit}",
          for_recipes: item.recipe_names
        }
      end),
      total_items: length(draft.items),
      confirmation_required: true,
      confirmation_action: "create_shopping_list",
      confirmation_data: %{
        start_date: args["start_date"],
        end_date: args["end_date"]
      }
    }
  end

  def execute("propose_meal_plan_entry", args, context) do
    recipe = Recipes.get_recipe!(args["recipe_id"], context.account)

    %{
      status: "proposal",
      message: "Would you like me to add this to your meal plan?",
      proposal: %{
        recipe_name: recipe.name,
        date: args["date"],
        meal_type: args["meal_type"],
        servings: args["servings"] || 4
      },
      confirmation_required: true,
      confirmation_action: "add_meal_plan_entry",
      confirmation_data: args
    }
  end
end
```

### LLM Integration (Claude API)

```elixir
defmodule GroceryPlanner.AI.Claude do
  @moduledoc """
  Client for Anthropic Claude API with tool use support.
  """

  @api_url "https://api.anthropic.com/v1/messages"

  def chat(messages, tools, opts \\ []) do
    body = %{
      model: Keyword.get(opts, :model, "claude-sonnet-4-20250514"),
      max_tokens: Keyword.get(opts, :max_tokens, 1024),
      system: Keyword.get(opts, :system_prompt),
      messages: format_messages(messages),
      tools: format_tools(tools)
    }

    case Req.post(@api_url, json: body, headers: auth_headers()) do
      {:ok, %{status: 200, body: body}} ->
        parse_response(body)
      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, message: body["error"]["message"]}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_tools(tools) do
    Enum.map(tools, fn tool ->
      %{
        name: tool.name,
        description: tool.description,
        input_schema: tool.parameters
      }
    end)
  end

  defp parse_response(%{"content" => content, "stop_reason" => stop_reason}) do
    case stop_reason do
      "tool_use" ->
        tool_calls = extract_tool_calls(content)
        {:ok, %{tool_calls: tool_calls}}
      "end_turn" ->
        text = extract_text(content)
        {:ok, %{content: text}}
    end
  end
end
```

## UI/UX Specifications

### Chat Interface

```heex
<div class="flex flex-col h-[600px] bg-base-100 rounded-xl border border-base-300">
  <!-- Header -->
  <div class="flex items-center justify-between p-4 border-b border-base-300">
    <div class="flex items-center gap-2">
      <.icon name="hero-sparkles" class="w-5 h-5 text-primary" />
      <span class="font-medium">Kitchen Assistant</span>
    </div>
    <button class="btn btn-ghost btn-sm" phx-click="new_conversation">
      <.icon name="hero-plus" class="w-4 h-4" />
    </button>
  </div>

  <!-- Messages -->
  <div class="flex-1 overflow-y-auto p-4 space-y-4" id="chat-messages" phx-hook="ScrollToBottom">
    <%= for message <- @messages do %>
      <div class={["chat", message_alignment(message.role)]}>
        <div class={["chat-bubble", message_style(message.role)]}>
          <%= if message.role == :assistant do %>
            <%= raw(Earmark.as_html!(message.content)) %>
          <% else %>
            <%= message.content %>
          <% end %>
        </div>

        <%= if message.tool_calls do %>
          <div class="chat-footer text-xs opacity-70 mt-1">
            <.icon name="hero-wrench-screwdriver" class="w-3 h-3 inline" />
            Called: <%= Enum.map(message.tool_calls, & &1.name) |> Enum.join(", ") %>
          </div>
        <% end %>
      </div>
    <% end %>

    <%= if @typing do %>
      <div class="chat chat-start">
        <div class="chat-bubble bg-base-200">
          <span class="loading loading-dots loading-sm"></span>
        </div>
      </div>
    <% end %>
  </div>

  <!-- Confirmation Banner (when action proposed) -->
  <%= if @pending_action do %>
    <div class="p-3 bg-primary/10 border-t border-primary/20">
      <p class="text-sm mb-2"><%= @pending_action.message %></p>
      <div class="flex gap-2">
        <button class="btn btn-sm btn-primary" phx-click="confirm_action">
          Confirm
        </button>
        <button class="btn btn-sm btn-ghost" phx-click="cancel_action">
          Cancel
        </button>
      </div>
    </div>
  <% end %>

  <!-- Input -->
  <form phx-submit="send_message" class="p-4 border-t border-base-300">
    <div class="flex gap-2">
      <input
        type="text"
        name="message"
        value={@input}
        placeholder="Ask about your kitchen..."
        class="input input-bordered flex-1"
        autocomplete="off"
        phx-change="update_input"
      />
      <button type="submit" class="btn btn-primary" disabled={@typing}>
        <.icon name="hero-paper-airplane" class="w-5 h-5" />
      </button>
    </div>
  </form>
</div>
```

### Suggested Prompts

```heex
<div class="grid grid-cols-2 gap-2 mb-4">
  <button
    class="btn btn-outline btn-sm justify-start"
    phx-click="send_message"
    phx-value-message="What's expiring soon?"
  >
    <.icon name="hero-clock" class="w-4 h-4" />
    What's expiring?
  </button>
  <button
    class="btn btn-outline btn-sm justify-start"
    phx-click="send_message"
    phx-value-message="What can I make for dinner tonight?"
  >
    <.icon name="hero-fire" class="w-4 h-4" />
    Dinner ideas
  </button>
  <button
    class="btn btn-outline btn-sm justify-start"
    phx-click="send_message"
    phx-value-message="Create a shopping list for this week"
  >
    <.icon name="hero-shopping-cart" class="w-4 h-4" />
    Shopping list
  </button>
  <button
    class="btn btn-outline btn-sm justify-start"
    phx-click="send_message"
    phx-value-message="What's on my meal plan this week?"
  >
    <.icon name="hero-calendar" class="w-4 h-4" />
    This week's plan
  </button>
</div>
```

### Streaming Responses

For better UX, stream assistant responses:

```elixir
def handle_event("send_message", %{"message" => message}, socket) do
  # Start async task for streaming
  task = Task.async(fn ->
    AI.Assistant.chat_stream(socket.assigns.conversation, message)
  end)

  {:noreply,
    socket
    |> assign(:typing, true)
    |> assign(:streaming_task, task)}
end

def handle_info({:stream_chunk, chunk}, socket) do
  # Append to current response
  current = socket.assigns.current_response || ""
  {:noreply, assign(socket, :current_response, current <> chunk)}
end

def handle_info({:stream_complete, response}, socket) do
  {:noreply,
    socket
    |> assign(:typing, false)
    |> assign(:current_response, nil)
    |> update(:messages, &(&1 ++ [response]))}
end
```

## Safety & Guardrails

### Never Allowed

1. **Deleting data** - No tool for deletion
2. **Modifying inventory** - Tools are read-only
3. **Creating without confirmation** - All writes require explicit user confirmation
4. **Accessing other accounts** - All queries scoped to user's account

### Confirmation Required For

1. Creating shopping lists
2. Adding meal plan entries
3. Any future write operations

### Response Guidelines

```elixir
@safety_prompt """
CRITICAL SAFETY RULES - You must follow these:

1. GROUNDING: Only reference items, recipes, and plans that exist in the user's data.
   - If a tool returns empty results, say "I don't see any..." not "You have..."
   - Never invent inventory items, recipes, or meal plans

2. CONFIRMATION: For any action that creates or modifies data:
   - Always show what will be created
   - Explicitly ask for confirmation
   - Wait for user to say "yes", "confirm", "do it", etc.

3. TRANSPARENCY: When you use a tool:
   - Briefly explain what you're checking
   - Summarize the results clearly
   - If something seems wrong, ask for clarification

4. LIMITATIONS: Be honest about what you can't do:
   - "I can help you find recipes, but I can't order groceries"
   - "I can show you expiring items, but you'll need to mark them as used"
"""
```

## Testing Strategy

### Unit Tests

```elixir
defmodule GroceryPlanner.AI.AssistantTest do
  use GroceryPlanner.DataCase

  describe "tool execution" do
    test "get_expiring_items returns real inventory data" do
      entry = create_inventory_entry(use_by_date: Date.add(Date.utc_today(), 3))

      result = ToolExecutor.execute("get_expiring_items", %{"days" => 7}, context)

      assert length(result.items) == 1
      assert hd(result.items).name == entry.grocery_item.name
    end

    test "draft_shopping_list requires confirmation" do
      result = ToolExecutor.execute("draft_shopping_list", %{...}, context)

      assert result.confirmation_required == true
      assert result.status == "draft"
    end
  end
end
```

### Conversation Tests

```elixir
test "assistant uses tools to answer expiring items question" do
  create_expiring_inventory(account)

  {:ok, result} = Assistant.chat(conversation, "What's expiring soon?")

  assert result.tool_results != nil
  assert Enum.any?(result.tool_results, & &1.name == "get_expiring_items")
  assert String.contains?(result.response, "expiring")
end

test "assistant asks for confirmation before creating shopping list" do
  {:ok, result} = Assistant.chat(conversation, "Create a shopping list for this week")

  assert String.contains?(result.response, "confirm")
  assert result.pending_action != nil
end
```

## Dependencies

### Elixir
- `req` - HTTP client
- `earmark` - Markdown rendering
- `jason` - JSON

### External
- Anthropic Claude API

## Configuration

```bash
# API Configuration
ANTHROPIC_API_KEY=sk-ant-...
CLAUDE_MODEL=claude-sonnet-4-20250514
CHAT_MAX_TOKENS=1024
CHAT_ENABLED=true

# Safety
CHAT_MAX_TOOL_CALLS_PER_TURN=5
CHAT_MAX_CONVERSATION_LENGTH=50
```

## Rollout Plan

1. **Phase 1:** Basic chat UI and infrastructure
2. **Phase 2:** Read-only tools (expiring, search, meal plan view)
3. **Phase 3:** Proposal tools (draft shopping list, propose meal)
4. **Phase 4:** Confirmation flow for writes
5. **Phase 5:** Streaming responses
6. **Phase 6:** Conversation history and feedback

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Tool grounding rate | 100% | Responses use tools, not hallucinations |
| Confirmation compliance | 100% | No writes without confirmation |
| Task completion rate | > 70% | User achieves goal via chat |
| User satisfaction | > 4/5 | Post-chat feedback |
| Response latency (p50) | < 3s | Time to first token |

## Open Questions

1. Should conversations persist across sessions?
2. Voice input support (mobile)?
3. Proactive notifications ("I noticed chicken is expiring...")?
4. Multi-turn context window size?

## References

- [Claude Tool Use Documentation](https://docs.anthropic.com/en/docs/build-with-claude/tool-use)
- [AI Backlog - AST-01](../docs/ai_backlog.md)
- [AI Integration Plan](../docs/ai_integration_plan.md)

## Implementation Status

**Status:** NOT YET IMPLEMENTED

All user stories (US-001 through US-005) and the UI/UX specifications remain valid requirements. However, the technical implementation approach described in the "Technical Specification" section above should be **superseded by AshAI** — see the AshAI Migration Plan below.

The safety guardrails, confirmation flow, and grounding requirements remain unchanged regardless of implementation approach.

## AshAI Migration Plan

[AshAI](https://hexdocs.pm/ash_ai/readme.html) (`ash_ai` hex package) provides native tool exposure, chat generation, and MCP server capabilities for Ash resources. This dramatically simplifies the planned implementation by replacing hand-rolled infrastructure with declarative Ash patterns.

### What AshAI Replaces

| Planned Component | Current Spec Approach | AshAI Approach |
|---|---|---|
| **Tool definitions** | Hand-crafted JSON schemas (6 tools, ~150 lines of JSON) | Ash actions automatically exposed as tools via `expose_as: :tool` on action definitions |
| **Tool executor** | Custom `ToolExecutor` module dispatching to domain functions | AshAI executes exposed actions directly — no manual dispatch needed |
| **Claude API client** | Custom `GroceryPlanner.AI.Claude` module with Req HTTP calls | AshAI handles LLM communication, including tool-call loops |
| **Conversation management** | Custom `Conversation` module building message arrays | `mix ash_ai.gen.chat` generates conversation management with persistence |
| **Chat UI** | Must build from scratch | `mix ash_ai.gen.chat` scaffolds a working LiveView chat interface |
| **MCP server** | Not planned | AshAI provides a free MCP server exposing all tool-enabled actions |

### What Stays the Same

These spec requirements are **unchanged** regardless of implementation approach:

- **User stories** (US-001 through US-005) — all requirements remain valid
- **Safety guardrails** — grounding, confirmation flows, no-deletion rules
- **Database schema** — `chat_conversations`, `chat_messages`, `chat_feedback` tables (AshAI may generate these or similar)
- **UI/UX design** — chat interface layout, suggested prompts, confirmation banners, streaming
- **Tool behavior** — the 6 tools still query the same domain functions, just exposed declaratively

### Revised Implementation Approach

#### Step 1: Add AshAI dependency

```elixir
# mix.exs
{:ash_ai, "~> 0.x"}
```

#### Step 2: Expose actions as tools

Instead of defining JSON schemas, annotate existing Ash read actions:

```elixir
# Example: In the InventoryEntry resource or a dedicated AI domain
# The exact AshAI DSL may vary — consult docs at implementation time
actions do
  read :get_expiring_items do
    argument :days, :integer, default: 7
    argument :limit, :integer, default: 10
    # ... filter logic ...
  end
end
```

Each of the 6 tools maps to an existing (or new) Ash action:
1. `get_expiring_items` → `InventoryEntry` read action with date filter
2. `search_recipes` → `Recipe` read action (leverages AI-002 hybrid search)
3. `get_recipe_details` → `Recipe` read action with ingredient loading
4. `get_meal_plan` → `MealPlanEntry` read action with date range filter
5. `draft_shopping_list` → Custom action returning a preview (no persist)
6. `propose_meal_plan_entry` → Custom action returning a proposal (no persist)

#### Step 3: Generate chat scaffolding

```bash
mix ash_ai.gen.chat
```

This generates conversation resources, LiveView components, and tool-calling infrastructure. Customize the generated code to match the UI/UX specifications in this document.

#### Step 4: Add safety layer

The system prompt and safety rules from the "Safety & Guardrails" section should be applied to the AshAI chat configuration. The confirmation flow for write operations (draft_shopping_list, propose_meal_plan_entry) needs custom handling on top of the generated scaffolding.

#### Step 5: Streaming and polish

AshAI's chat generation may include streaming support. If not, add streaming on top of the generated infrastructure using the patterns described in the "Streaming Responses" section of this spec.

### Rollout Plan (Revised)

The original 6-phase rollout remains valid but implementation effort is significantly reduced:

1. **Phase 1:** Add AshAI, run `mix ash_ai.gen.chat`, configure system prompt
2. **Phase 2:** Expose read-only actions as tools (expiring items, recipe search, meal plan view)
3. **Phase 3:** Add proposal actions (draft shopping list, propose meal plan entry)
4. **Phase 4:** Implement confirmation flow on top of generated UI
5. **Phase 5:** Streaming responses (may come free with AshAI)
6. **Phase 6:** Conversation history, feedback, and MCP server

### Open Questions (AshAI-Specific)

1. Does `mix ash_ai.gen.chat` generate conversation persistence, or do we still need the `chat_conversations`/`chat_messages` schema?
2. How does AshAI handle the confirmation/proposal pattern for write operations?
3. Can AshAI's tool exposure enforce read-only vs. write-with-confirmation semantics?
4. What LLM providers does AshAI support? (Claude is required for this spec)
5. How mature is the AshAI streaming support?

These questions should be answered by consulting the AshAI documentation and source code before implementation begins.
