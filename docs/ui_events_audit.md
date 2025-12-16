# UI Events and Handler Audit

_Last Updated: December 16, 2025_

This document tracks all UI events (`phx-click`, `phx-submit`, `phx-change`) and their corresponding backend `handle_event` handlers.

## Status Legend

- ✅ = Handler exists and matches
- ❌ = Handler missing or mismatched
- ⚠️ = Handler exists but may have param mismatch

---

## InventoryLive

| Event | Type | Handler | Status |
|-------|------|---------|--------|
| `change_tab` | phx-click | `handle_event("change_tab", %{"tab" => tab}, socket)` | ✅ |
| `clear_tag_filters` | phx-click | `handle_event("clear_tag_filters", _, socket)` | ✅ |
| `toggle_tag_filter` | phx-click | `handle_event("toggle_tag_filter", %{"tag-id" => id}, socket)` | ✅ |
| `new_item` | phx-click | `handle_event("new_item", _, socket)` | ✅ |
| `toggle_form_tag` | phx-click | `handle_event("toggle_form_tag", %{"tag-id" => id}, socket)` | ✅ |
| `cancel_form` | phx-click | `handle_event("cancel_form", _, socket)` | ✅ |
| `remove_tag_from_item` | phx-click | `handle_event("remove_tag_from_item", %{"tag-id" => id}, socket)` | ✅ |
| `add_tag_to_item` | phx-click | `handle_event("add_tag_to_item", %{"tag-id" => id}, socket)` | ✅ |
| `cancel_tag_management` | phx-click | `handle_event("cancel_tag_management", _, socket)` | ✅ |
| `manage_tags` | phx-click | `handle_event("manage_tags", %{"id" => id}, socket)` | ✅ |
| `edit_item` | phx-click | `handle_event("edit_item", %{"id" => id}, socket)` | ✅ |
| `delete_item` | phx-click | `handle_event("delete_item", %{"id" => id}, socket)` | ✅ |
| `new_entry` | phx-click | `handle_event("new_entry", _, socket)` | ✅ |
| `consume_entry` | phx-click | `handle_event("consume_entry", %{"id" => id}, socket)` | ✅ |
| `expire_entry` | phx-click | `handle_event("expire_entry", %{"id" => id}, socket)` | ✅ |
| `delete_entry` | phx-click | `handle_event("delete_entry", %{"id" => id}, socket)` | ✅ |
| `new_category` | phx-click | `handle_event("new_category", _, socket)` | ✅ |
| `delete_category` | phx-click | `handle_event("delete_category", %{"id" => id}, socket)` | ✅ |
| `new_location` | phx-click | `handle_event("new_location", _, socket)` | ✅ |
| `delete_location` | phx-click | `handle_event("delete_location", %{"id" => id}, socket)` | ✅ |
| `new_tag` | phx-click | `handle_event("new_tag", _, socket)` | ✅ |
| `edit_tag` | phx-click | `handle_event("edit_tag", %{"id" => id}, socket)` | ✅ |
| `delete_tag` | phx-click | `handle_event("delete_tag", %{"id" => id}, socket)` | ✅ |
| `save_item` | phx-submit | `handle_event("save_item", %{"item" => params}, socket)` | ✅ |
| `save_entry` | phx-submit | `handle_event("save_entry", %{"entry" => params}, socket)` | ✅ |
| `save_category` | phx-submit | `handle_event("save_category", %{"category" => params}, socket)` | ✅ |
| `save_location` | phx-submit | `handle_event("save_location", %{"location" => params}, socket)` | ✅ |
| `save_tag` | phx-submit | `handle_event("save_tag", %{"tag" => params}, socket)` | ✅ |

---

## SettingsLive

| Event | Type | Handler | Status |
|-------|------|---------|--------|
| `validate_account` | phx-change | `handle_event("validate_account", %{"account" => params}, socket)` | ✅ |
| `update_account` | phx-submit | `handle_event("update_account", %{"account" => params}, socket)` | ✅ |
| `validate_user` | phx-change | `handle_event("validate_user", %{"user" => params}, socket)` | ✅ |
| `update_user` | phx-submit | `handle_event("update_user", %{"user" => params}, socket)` | ✅ |
| `validate_notification` | phx-change | `handle_event("validate_notification", params, socket)` | ✅ |
| `save_notification` | phx-submit | `handle_event("save_notification", %{"notification" => params}, socket)` | ✅ |
| `show_invite_form` | phx-click | `handle_event("show_invite_form", _params, socket)` | ✅ |
| `hide_invite_form` | phx-click | `handle_event("hide_invite_form", _params, socket)` | ✅ |
| `validate_invitation` | phx-change | `handle_event("validate_invitation", %{"email" => email, "role" => role}, socket)` | ⚠️ |
| `send_invitation` | phx-submit | `handle_event("send_invitation", %{"email" => email, "role" => role}, socket)` | ⚠️ |
| `remove_member` | phx-click | `handle_event("remove_member", %{"id" => id}, socket)` | ✅ |

> ⚠️ **Note**: `validate_invitation` and `send_invitation` handlers expect direct params, not nested. Check if form uses `as: :invitation` wrapper.

---

## RecipesLive

| Event | Type | Handler | Status |
|-------|------|---------|--------|
| `new_recipe` | phx-click | Navigation via `navigate` | ✅ |
| `toggle_favorites` | phx-click | `handle_event("toggle_favorites", _, socket)` | ✅ |
| `view_recipe` | phx-click | `handle_event("view_recipe", %{"id" => id}, socket)` | ✅ |
| `toggle_favorite` | phx-click | `handle_event("toggle_favorite", %{"id" => id}, socket)` | ✅ |
| `search` | phx-change | `handle_event("search", %{"search" => term}, socket)` | ✅ |
| `filter_difficulty` | phx-change | `handle_event("filter_difficulty", %{"difficulty" => level}, socket)` | ✅ |

---

## RecipeFormLive

| Event | Type | Handler | Status |
|-------|------|---------|--------|
| `save` | phx-submit | `handle_event("save", %{"recipe" => params}, socket)` | ✅ |
| `toggle_favorite` | phx-click | `handle_event("toggle_favorite", _, socket)` | ✅ |
| `cancel` | phx-click | `handle_event("cancel", _, socket)` | ✅ |

---

## RecipeShowLive

| Event | Type | Handler | Status |
|-------|------|---------|--------|
| `toggle_favorite` | phx-click | `handle_event("toggle_favorite", _, socket)` | ✅ |
| `edit_recipe` | phx-click | `handle_event("edit_recipe", _, socket)` | ✅ |
| `delete_recipe` | phx-click | `handle_event("delete_recipe", _, socket)` | ✅ |
| `add_ingredient` | phx-click | `handle_event("add_ingredient", _, socket)` | ✅ |

---

## RecipeSearchLive

| Event | Type | Handler | Status |
|-------|------|---------|--------|
| `search` | phx-submit | `handle_event("search", %{"query" => query}, socket)` | ✅ |
| `random` | phx-click | `handle_event("random", _, socket)` | ✅ |
| `import` | phx-click | `handle_event("import", %{"id" => id}, socket)` | ✅ |

---

## MealPlannerLive

| Event | Type | Handler | Status |
|-------|------|---------|--------|
| `prev_week` | phx-click | `handle_event("prev_week", _params, socket)` | ✅ |
| `today` | phx-click | `handle_event("today", _params, socket)` | ✅ |
| `next_week` | phx-click | `handle_event("next_week", _params, socket)` | ✅ |
| `back_to_week` | phx-click | `handle_event("back_to_week", _params, socket)` | ✅ |
| `add_meal` | phx-click | `handle_event("add_meal", %{"date" => date, "meal_type" => type}, socket)` | ✅ |
| `edit_meal` | phx-click | `handle_event("edit_meal", %{"id" => id}, socket)` | ✅ |
| `remove_meal` | phx-click | `handle_event("remove_meal", %{"id" => id}, socket)` | ✅ |
| `select_day` | phx-click | `handle_event("select_day", %{"date" => date}, socket)` | ✅ |
| `close_modal` | phx-click | `handle_event("close_modal", _params, socket)` | ✅ |
| `prevent_close` | phx-click | `handle_event("prevent_close", _params, socket)` | ✅ |
| `select_recipe` | phx-click | `handle_event("select_recipe", %{"id" => id}, socket)` | ✅ |
| `close_edit_modal` | phx-click | `handle_event("close_edit_modal", _params, socket)` | ✅ |
| `update_meal` | phx-submit | `handle_event("update_meal", %{"servings" => s, "notes" => n}, socket)` | ✅ |
| `search_recipes` | phx-change (input) | `handle_event("search_recipes", %{"value" => term}, socket)` | ✅ |

---

## ShoppingLive

| Event | Type | Handler | Status |
|-------|------|---------|--------|
| `back_to_lists` | phx-click | `handle_event("back_to_lists", _params, socket)` | ✅ |
| `delete_list` | phx-click | `handle_event("delete_list", %{"id" => id}, socket)` | ✅ |
| `show_add_item_modal` | phx-click | `handle_event("show_add_item_modal", _params, socket)` | ✅ |
| `toggle_item` | phx-click | `handle_event("toggle_item", %{"id" => id}, socket)` | ✅ |
| `delete_item` | phx-click | `handle_event("delete_item", %{"id" => id}, socket)` | ✅ |
| `show_create_modal` | phx-click | `handle_event("show_create_modal", _params, socket)` | ✅ |
| `show_generate_modal` | phx-click | `handle_event("show_generate_modal", _params, socket)` | ✅ |
| `select_list` | phx-click | `handle_event("select_list", %{"id" => id}, socket)` | ✅ |
| `hide_create_modal` | phx-click | `handle_event("hide_create_modal", _params, socket)` | ✅ |
| `hide_generate_modal` | phx-click | `handle_event("hide_generate_modal", _params, socket)` | ✅ |
| `hide_add_item_modal` | phx-click | `handle_event("hide_add_item_modal", _params, socket)` | ✅ |
| `create_list` | phx-submit | `handle_event("create_list", %{"name" => name}, socket)` | ✅ |
| `generate_list` | phx-submit | `handle_event("generate_list", %{...}, socket)` | ✅ |
| `add_item` | phx-submit | `handle_event("add_item", %{...}, socket)` | ✅ |

---

## VotingLive

| Event | Type | Handler | Status |
|-------|------|---------|--------|
| `start_vote` | phx-click | `handle_event("start_vote", _, socket)` | ✅ |
| `finalize` | phx-click | `handle_event("finalize", _, socket)` | ✅ |
| `vote` | phx-click | `handle_event("vote", %{"id" => id}, socket)` | ✅ |

---

## SignUpLive

| Event | Type | Handler | Status |
|-------|------|---------|--------|
| `sign_up` | phx-submit | `handle_event("sign_up", params, socket)` | ✅ |
| `validate` | phx-change | `handle_event("validate", params, socket)` | ✅ |

---

## Summary

| LiveView | Total Events | Matched | Issues |
|----------|--------------|---------|--------|
| InventoryLive | 29 | 29 | ✅ |
| SettingsLive | 11 | 9 | ⚠️ 2 |
| RecipesLive | 6 | 6 | ✅ |
| RecipeFormLive | 3 | 3 | ✅ |
| RecipeShowLive | 4 | 4 | ✅ |
| RecipeSearchLive | 3 | 3 | ✅ |
| MealPlannerLive | 14 | 14 | ✅ |
| ShoppingLive | 14 | 14 | ✅ |
| VotingLive | 3 | 3 | ✅ |
| SignUpLive | 2 | 2 | ✅ |
| **Total** | **89** | **87** | **⚠️ 2** |

---

## Action Items

### SettingsLive - Invitation Form Handlers

The `validate_invitation` and `send_invitation` handlers expect direct params like `%{"email" => email, "role" => role}`, but need to verify the form template uses matching structure. If the form has `as: :invitation`, the handlers should accept `%{"invitation" => params}`.
