# Ash Direct Usage Audit

_Last Updated: December 16, 2025_

This document tracks all instances where we're directly using `Ash.read`, `Ash.create`, `Ash.update`, `Ash.destroy`, `Ash.get`, `Ash.load`, etc. instead of using code interfaces defined on domains.

## Status: ✅ All Critical Issues Fixed

All direct `Ash.read`, `Ash.read!`, and `Ash.get` calls have been migrated to use domain code interfaces.

---

## Acceptable Direct Usage

The following patterns are **acceptable** for direct Ash usage:

1. **`Ash.Query.*`** - Query building is fine; the query is passed to domain code interfaces
2. **`Ash.Changeset.*`** - Used inside resource changes/validations
3. **`Ash.exists?`** - Policy checks and constraints
4. **`Ash.count`** - Aggregation with domain specified
5. **`Ash.load/load!`** - Loading relationships on existing records (consider adding domain helpers)

---

## Changes Made (December 16, 2025)

### Analytics Domain
- ✅ Added `list_usage_logs` code interface
- ✅ Updated `get_waste_stats` to use `list_usage_logs`
- ✅ Updated `get_spending_trends` to use `list_inventory_entries`
- ✅ Updated `get_usage_trends` to use `list_usage_logs`
- ✅ Updated `get_most_wasted_items` to use `list_usage_logs`

### MealPlanning Domain
- ✅ Updated `EnsureNoOpenSession` change to use `list_vote_sessions`
- ✅ Updated `EnsureSessionOpen` change to use `get_vote_session`

---

## Remaining Items (Medium Priority)

### `Ash.load!` / `Ash.load` Calls

These are less critical since `Ash.load` on existing records is a common pattern. Consider adding domain convenience functions for frequently used patterns:

| File | Line | Pattern |
|------|------|---------|
| `api_auth.ex` | 12 | `Ash.load(user, :accounts)` |
| `recipe_show_live.ex` | 101, 111 | `Ash.load!(:recipe_ingredients)` |
| `settings_live.ex` | 14, 15, etc | `Ash.load!(:memberships, :user)` |
| `auth.ex` | 64 | `Ash.load!(user, [memberships: :account])` |
| Calculations | Various | Direct loading (acceptable in calculations) |

---

## Notes

- `Ash.Query.*` usage for building queries is **acceptable** - the query is passed to domain interfaces
- `Ash.Changeset.*` usage inside resource changes is **acceptable** - this is the intended pattern
- `Ash.count` with `domain:` option is **acceptable** - uses domain routing
- Policy checks using `Ash.exists?` are **acceptable**
