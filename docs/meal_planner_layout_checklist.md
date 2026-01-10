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
- [ ] Add an in-app layout switcher (without leaving `/meal-planner`)
- [ ] Add per-device override (optional; later)

### Shared interaction primitives (all layouts)
- [x] Shared recipe picker surface exists (modal / bottom sheet)
- [~] Shared add-to-plan flow (Explorer uses slot picker; other layouts partly overlap)
- [ ] Undo support for destructive/committing actions (remove meal, add meal, move meal)
- [ ] Skeleton/loading states for recipe lists and slot pickers
- [ ] Consistent terminology + labels across layouts (Day, Meal slot, Add, Swap, Clear)

---

## 1) Alternative A — Explorer Mode (Iteration 1)

### 1.1 Layout + information architecture
- [x] Planner context always present (timeline pane)
- [x] Recipe discovery feed present (cards)
- [~] Mobile-first explorer layout
  - [~] Search available at top of Explorer panel
  - [ ] Sticky top bar for Explorer on mobile (title + search)
  - [ ] Collapsible week timeline strip on mobile (compact by default)
  - [ ] Expands per day on tap
- [x] Desktop two-pane layout (timeline left, recipes right)

### 1.2 Week timeline strip
- [ ] Day chips (Mon–Sun) with indicators (planned count/missing dinner dot)
- [~] Mini agenda with meal slots (breakfast/lunch/dinner/snack)
- [x] Empty slot interaction: click/tap selects slot and prompts recipe picking
- [ ] “Missing dinner” dot indicator logic

### 1.3 Recipe discovery feed
- [x] Recipe cards with image/title/description
- [~] Tags on cards
  - [x] Difficulty badge
  - [ ] Time badge (total minutes)
  - [ ] Dietary/cuisine tags (if supported)
- [x] Primary CTA: Add to plan opens slot picker
- [x] Secondary actions: favorite toggle + details link
- [~] Favorites + Recents sections
  - [x] Favorites list visible when present
  - [x] Recently planned section
  - [ ] Empty states for Favorites/Recents (when they’re empty but overall feed exists)

### 1.4 Filters/sort
- [x] Quick filter (under 30 minutes)
- [~] Pantry-first filter
  - [ ] Implement actual pantry-first logic (currently no-op)
- [x] Difficulty filter
- [ ] Sort options (Trending/New/Quick/Lowest ingredients)
- [ ] Saved presets (Weeknight quick wins, Mediterranean)
- [ ] Mobile filter/sort bottom sheet

### 1.5 Micro-interactions
- [~] Transitions/hover polish on cards and buttons
- [ ] “Card flies to slot” animation on add-to-plan
- [ ] Slot confirmation toast with Undo
- [ ] Skeleton states during feed refresh

### 1.6 Empty/loading states
- [~] Empty Explore feed state
  - [x] “No recipes found” messaging
  - [x] Clear filters control (top + empty state)
  - [ ] Show “Relax filters” suggestions (suggested chips)
- [ ] Empty planner slot: show 3 quick picks (inline suggestions)

---

## 2) Alternative B — Focus Mode (Today-first)

### 2.1 Layout
- [ ] Sticky header: current day + week strip
- [ ] Main content: stacked meal slot cards
- [ ] Mobile FAB: Add meal
- [ ] Desktop 2-column: day details + grocery impact summary

### 2.2 Components
- [ ] Week strip (swipeable on mobile) with badges
- [ ] Slot cards: Swap / Clear / Add note
- [ ] Shortcuts: repeat last week / auto-fill day

### 2.3 Micro-interactions
- [ ] Tap-to-expand slot card
- [ ] Swipe actions on mobile (swap/delete)
- [ ] Skeleton loading on day switch

---

## 3) Alternative C — Power Mode (Kanban Week Board)

### 3.1 Layout
- [ ] Desktop/tablet Kanban grid (columns=days, cards=meals)
- [ ] Drag/drop meals across days + reorder within day
- [ ] Mobile simplified pager (one day visible) with reorder

### 3.2 Components
- [ ] Visible drop zones and highlights
- [ ] Recipe picker drawer (desktop slide-over / mobile bottom sheet)
- [ ] Command bar: auto-fill week / clear week / copy last week

### 3.3 Micro-interactions
- [ ] Drag lift + drop highlight
- [ ] Grocery delta feedback when moving meals (+/- items)
- [ ] Undo toast after destructive actions

---

## 4) “Next decisions” from the original doc

- [~] Explorer recipe details: dedicated view vs inline expand
  - [x] Dedicated details page exists
  - [ ] Inline expand (optional)
- [x] Favorites/Recents exist in Explorer
- [x] Layout setting is per-user
- [ ] Decide whether to support per-session/per-device override
