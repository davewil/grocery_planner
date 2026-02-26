# FM-001: Family Meal Planning — Brainstorm Output

**Status:** Design agreed
**Date:** 2026-02-23

## Problem Statement

In a family with conflicting eating requirements (e.g., 2 adults, 4 children — 1 vegetarian, 1 fussy eater with extremely limited acceptable meals), meal planning is painful. The goal is to **minimise the number of separate meals** that need to be prepared at any one meal time, while respecting everyone's dietary needs and preferences.

## Core Concept: Family Meals

A **Family Meal** is a pre-solved meal time solution. It documents: "When I cook X, here's what everyone eats." The parent's knowledge does the heavy lifting — the system helps them document and re-use their solutions.

**Example: "Spag Bol Night"**

| Member | Eats | Notes |
|--------|------|-------|
| You + Partner | Spaghetti Bolognese | Primary recipe |
| Child 1 & 2 | Spaghetti Bolognese | Same as adults |
| Lily (vegetarian) | Spaghetti Bolognese | Use veggie sauce instead of meat |
| Sam (fussy) | Chicken Nuggets & Chips | Separate recipe |

A meal time might require 1 recipe (everyone eats it), or 2-3 (with adaptations and separate dishes for members who can't be accommodated). The library of solved Family Meals lets the parent plan the week by picking from pre-figured-out solutions.

## Agreed Decisions

### 1. Family Member Profiles — Lightweight

- Parents create and manage profiles for children and non-tech-savvy members
- No login required for managed members — only account admins need a real `User` account
- Profiles live under the existing `Account` (which already represents a household)
- Minimal data: just a name. Parent knowledge handles the rest.

### 2. Family Meals — Solved Meal Time Solutions

- Parent creates a Family Meal: picks a primary recipe and assigns each member
- Members either eat the primary recipe (optionally with adaptation notes) or a separate alternative recipe
- Over time, parent builds a library of 15-20+ solved meal times
- When planning the week, pick from the library — the "what does everyone eat?" question is already answered

### 3. Minimal Data Model (v1)

**`FamilyMember`** — who's in the family
- `name` (string, required)
- `account_id` (multi-tenant)

**`FamilyMeal`** — a solved meal time
- `name` (string, required — e.g., "Spag Bol Night")
- `primary_recipe_id` (the main dish)
- `account_id` (multi-tenant)

**`FamilyMealMember`** — what each member eats in this meal
- `family_meal_id`
- `family_member_id`
- `alternative_recipe_id` (nullable — if null, eats the primary recipe)
- `notes` (nullable — adaptation notes, e.g., "veggie sauce instead of meat")

Three resources. Five meaningful fields. No over-engineering.

## Deferred to Future Iterations

- **Dietary restrictions per member** — Per-member dietary_needs tracking (vegan, gluten_free, etc.) for auto-filtering and compatibility scoring
- **Approved recipe whitelist** — Fussy eater whitelist (curated list of the only recipes a member will eat)
- **Compatibility scoring** — Auto-calculated recipe compatibility against family dietary profiles
- **Feedback/rating system** — Three-way rating (loved / ok / disliked) per member per recipe to organically surface popular recipes
- **Meal suggestion UX** — Smart recommendations at meal planning time (tiered view, smart suggestion, weekly planner)
- **Weekly planner optimisation** — Auto-generating a full week of meals minimising total separate meals
- **Integration with MealPlan** — Scheduling Family Meals to specific dates via existing MealPlan system

## Existing Codebase Context

The app already has foundations that this feature builds on:

- **Account = Family household** — multi-user accounts with memberships (owner/admin/member roles)
- **Recipe `dietary_needs` field** — 10 dietary types already modelled as an array of atoms
- **Meal voting** — `MealPlanVoteSession` / `MealPlanVoteEntry` for family decision-making
- **Meal plan templates** — reusable weekly plans with day/meal type slots
- **Inventory integration** — recipes know which ingredients are in stock via calculations
- **AI embeddings** — recipes vectorised for semantic search (384-dim)

## Implementation Scope (v1)

1. `FamilyMember` resource (name + account scoping)
2. `FamilyMeal` resource (name + primary recipe)
3. `FamilyMealMember` join resource (member assignments with optional alternative recipe + notes)
4. Basic UI: manage family members, create/edit family meals, browse library
