# Component Library Reference

**Version:** 1.0
**Last Updated:** January 3, 2026
**Location:** `lib/grocery_planner_web/components/`

---

## Overview

This document provides a reference for standardized UI components in GroceryPlanner. These components ensure consistent styling, behavior, and theming across the application.

## Component Modules

### 1. Core Components (`core_components.ex`)
Phoenix-generated components with some customizations:
- `modal/1` - Modal dialog overlay
- `flash/1` - Flash message notifications
- `button/1` - Standard button component
- `input/1` - Form input fields
- `icon/1` - Hero icon wrapper

### 2. UI Components (`ui_components.ex`)
Custom reusable components for GroceryPlanner:
- `empty_state/1` - Empty state placeholder
- `stat_card/1` - KPI/statistic display card

---

## UI Components API

### `empty_state/1`

**Purpose:** Display when lists or collections have no items

**Attributes:**
| Attribute | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `icon` | string | ✅ | - | Heroicon name (e.g., `"hero-cube"`) |
| `title` | string | ✅ | - | Main message |
| `description` | string | ❌ | nil | Secondary message |
| `padding` | string | ❌ | `"py-16"` | Tailwind padding class |

**Slots:**
- `action` - Optional slot for action button

**Examples:**

```heex
<!-- Basic empty state -->
<.empty_state
  icon="hero-book-open"
  title="No recipes yet"
  description="Click 'New Recipe' to add your first recipe"
/>

<!-- With action button -->
<.empty_state icon="hero-shopping-cart" title="No shopping lists">
  <:action>
    <.button phx-click="new_list" class="btn-primary mt-4">
      Create List
    </.button>
  </:action>
</.empty_state>

<!-- With conditional rendering -->
<.empty_state
  :if={@items == []}
  icon="hero-cube"
  title="No items found"
  padding="py-12"
/>
```

**Before vs After:**

```heex
<!-- ❌ OLD: Repetitive code -->
<div :if={@recipes == []} class="text-center py-16">
  <svg class="w-16 h-16 text-base-content/20 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
  </svg>
  <p class="text-base-content/50 font-medium">No recipes yet</p>
  <p class="text-base-content/30 text-sm mt-1">Click "New Recipe" to add your first recipe</p>
</div>

<!-- ✅ NEW: Clean and consistent -->
<.empty_state
  :if={@recipes == []}
  icon="hero-book-open"
  title="No recipes yet"
  description="Click 'New Recipe' to add your first recipe"
/>
```

---

### `stat_card/1`

**Purpose:** Display KPI metrics and statistics with consistent styling

**Attributes:**
| Attribute | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `icon` | string | ✅ | - | Heroicon name |
| `color` | string | ✅ | - | Semantic color (see color reference) |
| `label` | string | ✅ | - | Metric label |
| `value` | string | ✅ | - | Main value to display |
| `description` | string | ❌ | nil | Additional context |
| `link` | string | ❌ | nil | If provided, card becomes clickable |
| `value_suffix` | string | ❌ | nil | Suffix for value (e.g., "items") |

**Color Reference:**
- `"primary"` - Primary theme color
- `"secondary"` - Secondary theme color
- `"accent"` - Accent theme color
- `"success"` - Green (positive metrics)
- `"warning"` - Yellow/orange (warnings)
- `"error"` - Red (critical alerts)
- `"info"` - Blue (informational)

**Examples:**

```heex
<!-- Static stat card -->
<.stat_card
  icon="hero-cube"
  color="primary"
  label="Total Inventory"
  value="127"
  value_suffix="items"
  description="15 individual units"
/>

<!-- Clickable alert card -->
<.stat_card
  icon="hero-fire"
  color="error"
  label="Expired"
  value="3"
  description="Remove immediately"
  link={~p"/inventory?expiring=expired"}
/>

<!-- Success metric -->
<.stat_card
  icon="hero-currency-dollar"
  color="success"
  label="Total Value"
  value="$342.50"
  description="Estimated based on purchase price"
/>

<!-- Grid of stat cards -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
  <.stat_card
    icon="hero-cube"
    color="primary"
    label="Total Items"
    value={to_string(@inventory_summary.total_items)}
  />

  <.stat_card
    icon="hero-exclamation-triangle"
    color="warning"
    label="Expiring Soon"
    value={to_string(@expiration_summary.expiring_7_days)}
    description="#{@expiration_summary.expired_count} already expired"
  />
</div>
```

**Before vs After:**

```heex
<!-- ❌ OLD: Verbose and repetitive -->
<div class="bg-base-100 p-6 rounded-2xl shadow-sm border border-base-200">
  <div class="flex items-center gap-4">
    <div class="w-12 h-12 bg-primary/10 rounded-xl flex items-center justify-center text-primary">
      <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
      </svg>
    </div>
    <div>
      <p class="text-sm font-medium text-base-content/60">Total Inventory</p>
      <div class="flex items-baseline gap-2">
        <h3 class="text-2xl font-bold text-base-content">{@inventory_summary.total_items}</h3>
        <span class="text-sm text-base-content/60">items</span>
      </div>
    </div>
  </div>
</div>

<!-- ✅ NEW: Concise and maintainable -->
<.stat_card
  icon="hero-cube"
  color="primary"
  label="Total Inventory"
  value={to_string(@inventory_summary.total_items)}
  value_suffix="items"
/>
```

---

## Usage Guide

### Setting Up in a LiveView

1. **Import the module:**
   ```elixir
   defmodule GroceryPlannerWeb.MyLive do
     use GroceryPlannerWeb, :live_view
     import GroceryPlannerWeb.UIComponents  # ← Add this

     # ... rest of your LiveView
   end
   ```

2. **Use in template:**
   ```heex
   <.empty_state
     :if={@items == []}
     icon="hero-inbox"
     title="No items"
   />
   ```

### Icon Reference

All components use Heroicons v2. Common icons:

| Icon Name | Usage |
|-----------|-------|
| `hero-book-open` | Recipes |
| `hero-shopping-cart` | Shopping lists |
| `hero-cube` | Inventory items |
| `hero-calendar` | Meal plans |
| `hero-chart-bar` | Analytics |
| `hero-exclamation-triangle` | Warnings |
| `hero-fire` | Critical alerts |
| `hero-currency-dollar` | Money/pricing |
| `hero-users` | Account members |

Full icon reference: https://heroicons.com/

---

## Theme Compatibility

All UI components are **fully theme-aware** and work across all 12 daisyUI themes:
- light, dark, cupcake, bumblebee, synthwave, retro
- cyberpunk, dracula, nord, sunset, business, luxury

Components use semantic color classes that automatically adapt:
- `text-base-content` - adapts to theme
- `bg-base-100`, `bg-base-200` - background layers
- `border-base-200` - borders
- `text-{color}` where color is semantic (primary, success, etc.)

---

## Migration Guide

### Refactoring Existing Code

1. **Identify duplicate patterns** (use COMPONENT_AUDIT.md)
2. **Import UIComponents** in LiveView module
3. **Replace verbose code** with component
4. **Test** in multiple themes
5. **Commit** changes

### Example Migration Steps:

```elixir
# Step 1: Find empty state pattern in your LiveView template
<div :if={@items == []} class="text-center py-16">
  <svg>...</svg>
  <p>No items yet</p>
</div>

# Step 2: Add import to LiveView module
defmodule GroceryPlannerWeb.MyLive do
  use GroceryPlannerWeb, :live_view
  import GroceryPlannerWeb.UIComponents  # ← Add this
end

# Step 3: Replace with component
<.empty_state
  :if={@items == []}
  icon="hero-inbox"
  title="No items yet"
/>

# Step 4: Test compilation
mix compile

# Step 5: Run tests
mix test
```

---

## Best Practices

### 1. **Choose Appropriate Icons**
Match the icon to the context:
```heex
<!-- ✅ GOOD: Icon matches content -->
<.empty_state icon="hero-book-open" title="No recipes" />

<!-- ❌ BAD: Icon doesn't match -->
<.empty_state icon="hero-shopping-cart" title="No recipes" />
```

### 2. **Use Semantic Colors**
Always use semantic colors for stat_card:
```heex
<!-- ✅ GOOD: Semantic color for alerts -->
<.stat_card color="error" label="Expired" value="3" />

<!-- ❌ BAD: Don't use arbitrary colors -->
<.stat_card color="red" label="Expired" value="3" />
```

### 3. **Consistent Wording**
Use consistent language for empty states:
```heex
<!-- ✅ GOOD: Clear and actionable -->
<.empty_state
  title="No recipes yet"
  description="Click 'New Recipe' to add your first recipe"
/>

<!-- ❌ BAD: Vague messaging -->
<.empty_state title="Nothing here" />
```

### 4. **Conditional Rendering**
Use `:if` attribute directly on components:
```heex
<!-- ✅ GOOD: Clean conditional -->
<.empty_state :if={@items == []} icon="hero-inbox" title="No items" />

<!-- ❌ BAD: Extra div wrapper -->
<div :if={@items == []}>
  <.empty_state icon="hero-inbox" title="No items" />
</div>
```

---

## Future Components (Roadmap)

Based on COMPONENT_AUDIT.md, these components are planned:

- **Phase 2:**
  - `page_header/1` - Page title with description and actions
  - `section/1` - Section container with title
  - `list_item/1` - Horizontal list item with icon

- **Phase 3:**
  - `nav_card/1` - Navigation cards (Dashboard style)
  - `item_card/1` - Recipe/item cards with image
  - `bar_chart/1` - CSS-based bar chart visualization
  - `alert_banner/1` - Info/warning banners

---

## Testing Components

### Manual Testing Checklist

- [ ] Component renders correctly in light theme
- [ ] Component renders correctly in dark theme
- [ ] Component is responsive (mobile, tablet, desktop)
- [ ] Conditional rendering works (`:if` attribute)
- [ ] Hover states work (if applicable)
- [ ] Click actions work (if clickable)
- [ ] Icons display properly
- [ ] Text is readable across all themes

### Automated Testing

Components are tested indirectly through LiveView tests. When refactoring to use components:

1. Existing tests should still pass
2. No new tests needed if behavior is identical
3. Add tests if new functionality is added

---

## Support & Contribution

### Questions?
- Check `COMPONENT_AUDIT.md` for analysis and recommendations
- Review component source: `lib/grocery_planner_web/components/ui_components.ex`
- Ask in team chat

### Contributing New Components
1. Identify duplicate pattern (3+ instances)
2. Design component API (attributes, slots)
3. Implement in `ui_components.ex`
4. Add documentation here
5. Refactor 1-2 pages as proof of concept
6. Submit PR with examples

---

**Last Updated:** January 3, 2026
**Maintained By:** GroceryPlanner Development Team
