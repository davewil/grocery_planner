# Meal Planner UI Improvements (3 Design Alternatives)

## Goals
- Modern, responsive, **mobile-first** UI that feels elegant, fast, and engaging.
- Improve discoverability and reduce decision fatigue.
- Support **multiple UI modes** so users can choose the experience that fits their planning style.
- Keep interactions and information architecture consistent across modes (so switching modes is not jarring).

## Primary user persona for Iteration 1: Foodie Explorers
Foodie explorers:
- Browse and discover new recipes first; planning is a byproduct of inspiration.
- Prefer strong visuals, tags, and quick “save / add to plan” actions.
- Benefit from curated suggestions and gentle guidance (time, dietary, popularity, seasonality).

### Success metrics (explorers)
- Higher “Add to plan” conversion from discovery.
- Lower time-to-first-meal-added.
- More repeat usage (favorites, recents).

---

## Alternative A (Iteration 1): Recipe-centric Planner + Timeline (Explorer Mode)
**Positioning:** discovery-led planning with a planner always visible.

### Information architecture
- **Planner context always present** (compact weekly timeline strip).
- Main content is a **Recipe Discovery Feed** with search and filters.

### Core layout
**Mobile-first**
- Sticky top bar: page title + search.
- **Collapsible Week Timeline** just below (compact by default; expands per day).
- Main content: recipe feed (cards).
- Bottom action: Filter/Sort button opening a bottom sheet.

**Desktop**
- Two-pane layout:
  - Left pane: week timeline + day detail.
  - Right pane: recipe feed + filters.

### Key components
1. **Week Timeline Strip**
   - Days as compact chips (Mon–Sun) with quick indicators: planned count, “missing dinner” dot.
   - Tap a day expands a mini agenda showing Breakfast/Lunch/Dinner slots.

2. **Recipe Discovery Feed**
   - Visual recipe cards: image, title, tags (time, cuisine, dietary), popularity/favorite.
   - Primary CTA: **“Add to…”** opens quick picker (day + meal slot) without leaving the feed.
   - Secondary actions: Save/Favorite, View details.

3. **Filter/Sort Bottom Sheet (mobile) / Sticky Sidebar (desktop)**
   - Quick toggles (chips): Under 30 min, High protein, Vegetarian, Pantry-first.
   - Sort: Trending, New, Quick, Lowest ingredients.
   - Saved filter presets (“Weeknight quick wins”, “Mediterranean”) for explorers.

### Micro-interactions
- “Add to plan” triggers a **light animation** (card visually “flies” to the selected slot).
- Slot confirmation toast with **Undo**.
- Skeleton states during feed refresh.

### Empty and loading states
- Empty planner slot: “Add something delicious” + 3 quick picks.
- Empty feed: show “Relax filters” suggestions.

### Why this is the best first iteration
- Maximizes engagement and discovery.
- Makes planning feel effortless and fun.
- Keeps the current task (browsing) while supporting planning context.

---

## Alternative B: Today-first Dashboard (Focus Mode)
**Positioning:** minimal, fast day-by-day planning.

### Core layout
**Mobile-first**
- Sticky header: current day + week strip.
- Main content: stacked meal slot cards (Breakfast/Lunch/Dinner).
- Floating primary action (FAB): Add meal.

**Desktop**
- 2-column:
  - Left: day details.
  - Right: grocery impact summary + quick actions.

### Key components
- **Week Strip** (swipeable): day chips with badges.
- **Meal Slot Cards** with quick actions: Swap, Clear, Add note.
- “Repeat last week” / “Auto-fill day” shortcuts.

### Micro-interactions
- Tap-to-expand slot card for details.
- Swipe actions on mobile: swap/delete.
- Subtle skeleton loading on day switch.

### Why users like it
- Lowest cognitive load.
- Optimized for quick planning and repeatable routines.

---

## Alternative C: Kanban Week Board (Power Mode)
**Positioning:** highly interactive week-at-a-glance planning.

### Core layout
**Desktop/tablet**
- Kanban grid: columns = days, cards = meals.
- Drag/drop to reorder or move meals across days.

**Mobile**
- Reduced complexity: day pager (one day visible), still supports reorder.

### Key components
- **Board Grid** with visible drop zones.
- **Recipe picker drawer** (desktop slide-over / mobile bottom sheet).
- “Auto-fill week”, “Clear week”, “Copy last week” command bar.

### Micro-interactions
- Drag lift + drop highlight.
- Grocery delta feedback (“+2 items, -1 items”) when moving meals.
- Undo toast after destructive actions.

### Why it’s strong
- Feels premium and dynamic.
- Very fast for weekly planning once learned.

---

## Unifying principles across all modes
- Consistent terminology: Day, Meal slot, Add, Swap, Clear.
- Consistent recipe card design and actions (Save, Add to plan).
- Shared “recipe picker” surface (drawer/bottom sheet) that adapts per mode.
- Always accessible Undo for changes.

---

## Make these alternatives a user setting (UI Mode)
The goal is to let users choose a UI that matches their style:

### Proposed setting
- **Setting name:** Meal Planner Layout
- **Options:**
  1. Explorer (Recipe Feed + Timeline) — default
  2. Focus (Today-first)
  3. Power (Kanban Board)

### Where it lives
- User Settings → Preferences → Meal Planner Layout
- Also offer a lightweight in-app switcher (optional): a small “Layout” icon/button in the meal planner header.

### Persistence
- Store on the user profile (server-side), with a safe fallback to Explorer.
- Allow per-device override later if useful.

### Rollout plan
1. Ship Explorer mode first.
2. Add settings scaffolding early, even if only one option exists initially.
3. Gradually add Focus mode, then Power mode.

---

## Implementation notes (high-level)
- The app should treat the layout as a runtime-selectable “view strategy” that:
  - reuses the same meal data and actions;
  - renders different compositions and interaction affordances.
- Avoid fragmenting business logic—only the layout changes; the underlying operations remain shared.

---

## Next decisions (to proceed cleanly)
1. Should Explorer mode include a dedicated recipe details view, or expand inline?
2. Do we have Favorites/Recents already, or should we add them as part of Explorer?
3. Should the layout setting be per-user (recommended) or per-session?
