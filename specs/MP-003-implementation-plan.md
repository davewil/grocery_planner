# MP-003 Power Mode - Implementation Plan

> Captured from planning session on 2026-01-12

## Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Drag-drop library | **SortableJS** | Excellent touch/mobile support, smooth animations, ~10KB, supports drag between groups |
| Mobile UX | **Horizontal scroll kanban** | Preserves week-at-a-glance on tablets, consistent with desktop |
| Slot conflicts | **Show swap confirmation** | Drop on occupied slot prompts "Swap with X?" before committing |
| Auto-fill algorithm | **Pantry-optimized** | Prefer recipes using ingredients already in inventory |

## PR Breakdown

### PR 1: DnD Basics ✅ COMPLETED
**Focus:** Core drag-and-drop functionality

- [x] Install SortableJS via npm (`npm install sortablejs`)
  - Added to `assets/vendor/sortable.js` (following project convention)
- [x] Create `assets/js/hooks/kanban_board.js` hook
  - Initialize SortableJS on mount
  - Configure drag handles, animation, ghost class
  - Push `drag_start`, `drag_end`, `drop_meal` events to LiveView
- [x] Update `PowerLayout` module
  - Add `data-*` attributes for sortable groups
  - Visual drop zone highlighting during drag
  - Opacity change on dragged card
- [x] Implement swap confirmation modal
  - Show when dropping on occupied slot
  - Options: "Swap", "Cancel"
  - Animate swap if confirmed
- [x] Integrate with existing `UndoSystem`
  - Push `:move_meal` actions to undo stack
  - Support undo/redo for moves
  - Added `:swap_meals` undo action
- [x] Add LiveView event handlers in main `MealPlannerLive`
  - `handle_event("drop_meal", ...)` - move meal to new date/slot
  - `handle_event("drop_recipe", ...)` - add meal from sidebar
  - `handle_event("confirm_swap", ...)` / `handle_event("cancel_swap", ...)` - swap two meals
  - Bulk operations: `clear_week`, `copy_last_week`, `auto_fill_week`
  - Selection: `toggle_meal_selection`, `select_all`, `clear_selection`, `delete_selected`
- [x] Tests
  - LiveView tests for drag events via `render_hook/3`
  - Undo/redo after move
  - Swap confirmation flow
  - 15 tests in `meal_planner_power_mode_test.exs`

### PR 2: Recipe Sidebar ✅ COMPLETED (merged into PR 1)
**Focus:** Collapsible sidebar with drag-to-add

- [x] Add sidebar state to `@power_assigns`
  - `sidebar_open: true`
  - `sidebar_search: ""`
  - `sidebar_recipes: []`
- [x] Create sidebar component in `PowerLayout`
  - Collapsible with toggle button
  - Search input with debounced filtering
  - Sections: Favorites, Recent, All Recipes
- [x] Make sidebar recipes draggable
  - Different SortableJS group (`recipes` -> `meals`)
  - `pull: 'clone'` so recipes aren't removed from sidebar
- [x] Handle `drop_recipe` event
  - Create new `MealPlan` at target date/slot
  - Push to undo stack
- [x] Tests
  - Sidebar toggle
  - Drag recipe to board creates meal
  - [ ] Search filtering (UI wired, filtering logic TODO)

### PR 3: Bulk Operations ✅ COMPLETED (merged into PR 1)
**Focus:** Week-level operations and multi-select

- [x] Command bar with bulk action buttons
  - "Clear Week" with confirmation
  - "Copy Last Week"
  - "Select All" / "Clear Selection"
- [x] Multi-select functionality
  - Checkbox on each meal card (visible on hover)
  - `selected_meals: MapSet.new()` in assigns
  - "Delete Selected" action
- [x] Keyboard shortcuts via hook
  - `Ctrl/Cmd + Z` - Undo
  - `Ctrl/Cmd + Shift + Z` - Redo
  - `Delete` / `Backspace` - Delete selected
  - `Escape` - Clear selection
- [x] Implement bulk handlers
  - `handle_event("clear_week", ...)` - delete all meals in week
  - `handle_event("copy_last_week", ...)` - duplicate previous week's meals
  - `handle_event("delete_selected", ...)` - batch delete
  - `handle_event("auto_fill_week", ...)` - pantry-optimized auto-fill
- [x] Tests
  - Clear week removes all meals
  - Copy last week creates duplicates
  - Multi-select and delete

### PR 4: Polish (REMAINING WORK)
**Focus:** Grocery feedback, search filtering, refinements

- [x] Pantry-optimized auto-fill (completed in PR 1)
  - Query recipes sorted by ingredient availability
  - Fill empty slots without repeating recipes
  - Show toast with summary ("Added 5 meals")
- [ ] Grocery delta feedback during drag
  - Calculate +/- shopping items when hovering over drop zone
  - Show floating toast: "+2 items" / "-1 item"
  - Update `week_shopping_items` after drop
- [ ] Sidebar search filtering
  - Wire up `search_sidebar` event to filter recipes list
  - Debounced search
- [ ] Mobile refinements
  - Test horizontal scroll on various devices
  - Adjust card sizes for touch targets
  - Ensure swipe doesn't conflict with scroll
- [ ] Visual polish
  - Drag ghost styling refinements
  - Drop zone highlight animation
  - Success/error feedback animations
- [ ] Tests
  - Grocery delta calculations
  - Sidebar search filtering

## File Changes Summary

### New Files
```
assets/js/hooks/kanban_board.js       # SortableJS integration
```

### Modified Files
```
assets/js/hooks/index.js              # Export new hook
assets/js/app.js                      # Register hook (if needed)
package.json                          # Add sortablejs dependency
lib/grocery_planner_web/live/meal_planner_live/power_layout.ex
lib/grocery_planner_web/live/meal_planner_live.ex  # New event handlers
```

## Dependencies

```json
{
  "sortablejs": "^1.15.0"
}
```

## References

- [MP-003 Spec](./MP-003-power-mode.md)
- [SortableJS Docs](https://sortablejs.github.io/Sortable/)
- [Meal Planner Layout Checklist](../docs/meal_planner_layout_checklist.md)
