# Meal Planner Layout Checklist (tracked roadmap)

This checklist turns `docs/ui_improvements_meal_planner.md` into trackable work.

Legend:
- [x] Done
- [ ] Not done
- [~] Partial / in progress

---

## 0) Cross-cutting prerequisites

### Data + settings
- [x] Meal Planner Layout stored on user profile (`meal_planner_layout`)
- [x] Settings UI to choose Explorer / Focus / Power
- [x] Meal Planner header shows current layout and provides a path to change it
- [x] Add an in-app layout switcher (without leaving `/meal-planner`)
- [ ] Add per-device override (optional; later)

### Shared interaction primitives (all layouts)
- [x] Shared recipe picker surface exists (modal / bottom sheet)
- [x] Shared add-to-plan flow (Explorer uses slot picker; other layouts partly overlap)
- [x] Undo support for destructive/committing actions (remove meal, add meal, move meal)
- [x] Skeleton/loading states for recipe lists and slot pickers
- [x] Consistent terminology + labels across layouts (Day, Meal slot, Add, Swap, Clear)

---

## 1) Alternative A — Explorer Mode (Iteration 1)

### 1.1 Layout + information architecture
- [x] Planner context always present (timeline pane)
- [x] Recipe discovery feed present (cards)
- [x] Mobile-first explorer layout
  - [x] Search available at top of Explorer panel
  - [x] Sticky top bar for Explorer on mobile (title + search)
  - [x] Collapsible week timeline strip on mobile (compact by default)
  - [x] Expands per day on tap
- [x] Desktop two-pane layout (timeline left, recipes right)

### 1.2 Week timeline strip
- [x] Day chips (Mon–Sun) with indicators (planned count/missing dinner dot)
- [x] Mini agenda with meal slots (breakfast/lunch/dinner/snack)
- [x] Empty slot interaction: click/tap selects slot and prompts recipe picking
- [x] “Missing dinner” dot indicator logic

### 1.3 Recipe discovery feed
- [x] Recipe cards with image/title/description
- [x] Tags on cards
  - [x] Difficulty badge
  - [x] Time badge (total minutes)
  - [x] Ingredient availability / Shopping need badge
  - [x] Dietary/cuisine tags (if supported)
- [x] Primary CTA: Add to plan opens slot picker
- [x] Secondary actions: favorite toggle + details link
- [x] Favorites + Recents sections
  - [x] Favorites list visible when present
  - [x] Recently planned section
  - [x] Empty states for Favorites/Recents (handled by hiding or logic)

### 1.4 Filters/sort
- [x] Quick filter (under 30 minutes)
- [x] Pantry-first filter
  - [x] Implemented a pantry-first heuristic (sort by fewest ingredients)
- [x] Difficulty filter
- [x] Sort options (Name/Newest/Prep Time/Difficulty)
- [ ] Saved presets (Weeknight quick wins, Mediterranean)
- [ ] Mobile filter/sort bottom sheet

---

## 2) Alternative B — Focus Mode (Today-first)

### 2.1 Layout
- [x] Sticky header: current day + week strip
- [x] Main content: stacked meal slot cards
- [x] Mobile FAB: Add meal (Quick picker bottom sheet)
- [x] Desktop 2-column: day details + grocery impact summary

### 2.2 Components
- [x] Week strip (swipeable on mobile) with badges
- [x] Slot cards: Swap / Clear / Add note
- [x] Shortcuts: repeat last week / auto-fill day
- [x] Meal Prep Mode: Repeat same meal across days

### 2.3 Micro-interactions
- [x] Inline notes editing
- [x] Long-press for more options (mobile)
- [x] Swipe actions on mobile (swap/delete)
- [x] Skeleton loading on day switch
- [x] Grocery impact tally per meal and per day

---

## 3) Alternative C — Power Mode (Kanban Week Board)

### 3.1 Layout
- [x] Desktop/tablet Kanban grid (columns=days, cards=meals)
- [x] Drag/drop meals across days + reorder within day
- [x] Mobile simplified pager (one day visible) with reorder
  - [x] Horizontal scroll kanban on mobile (alternative approach)
  - [x] Single-day pager view

### 3.2 Components
- [x] Visible drop zones and highlights
- [x] Recipe picker drawer (desktop slide-over / mobile bottom sheet)
  - [x] Collapsible sidebar with search, favorites, recent
  - [x] Drag recipes from sidebar to board
- [x] Command bar: auto-fill week / clear week / copy last week
  - [x] Clear week with confirmation
  - [x] Copy last week
  - [x] Auto-fill week (pantry-optimized)
  - [x] Multi-select meals + delete selected

### 3.3 Micro-interactions
- [x] Drag lift + drop highlight (SortableJS)
- [x] Swap confirmation modal when dropping on occupied slot
- [x] Grocery delta feedback when moving meals (+/- items)
- [x] Undo toast after destructive actions
- [x] Keyboard shortcuts (Ctrl+Z undo, Ctrl+Shift+Z redo, Delete selected, etc.)

---

## 4) “Next decisions” from the original doc

- [~] Explorer recipe details: dedicated view vs inline expand
  - [x] Dedicated details page exists
  - [ ] Inline expand (optional)
- [x] Favorites/Recents exist in Explorer
- [x] Layout setting is per-user
- [ ] Decide whether to support per-session/per-device override