# SMT Solver Recipe Optimization

## Overview

This document outlines a proposed feature to utilize Satisfiability Modulo Theories (SMT) solvers, such as Z3, to intelligently optimize meal planning. By treating recipe selection as a constraint satisfaction problem, we can offer powerful new capabilities to users, such as minimizing food waste by prioritizing expiring ingredients and finding the best recipes for a specific set of available ingredients.

## Problem Statement

Users often face two paralysis points in meal planning:
1.  **"What do I cook with this?"**: Having a random assortment of ingredients (some expiring) and not knowing how to combine them efficiently.
2.  **"I want to use X, Y, and Z"**: Wanting to use specific ingredients but struggling to find a recipe that uses *most* of them without requiring a shopping trip for many extra items.

Traditional search (e.g., "recipes with chicken") is often insufficient because it doesn't account for the *state* of the inventory (expiration dates) or complex constraints (minimize missing ingredients while maximizing use of expiring ones).

## Proposed Solution

We propose integrating an SMT solver to power two key features:

### 1. "Optimize My Fridge" (Expiration Optimization)
**Goal**: Suggest a set of recipes that maximizes the usage of ingredients expiring within the next X days.
**Constraints**:
- Must use ingredients with `days_until_expiry <= threshold`.
- Minimize the number of *new* ingredients required (shopping list size).
- Respect dietary restrictions (if implemented).

### 2. "Cook With..." (Ingredient Minimization)
**Goal**: Given a user-selected list of ingredients, find recipes that use as many of them as possible while minimizing missing ingredients.
**Constraints**:
- `Maximize(Selected Ingredients Used)`
- `Minimize(Missing Ingredients)`

## Technical Concept

SMT solvers are designed to find a solution that satisfies a set of logical constraints. We can model our domain as follows:

### Inputs
- **Inventory**: List of available items $I_{avail}$ with quantities and expiration dates.
- **Recipes**: List of recipes $R$, where each recipe $r$ has a set of required ingredients $I_r$.
- **User Constraints**: Specific ingredients to use $I_{user}$, dietary restrictions, etc.

### Solver Logic (Conceptual)

We can define boolean variables for each recipe $x_r$ (1 if selected, 0 if not).

**Objective Function Examples:**

*Maximize Usage of Expiring Items:*
$$ \text{Maximize} \sum_{r \in R} (x_r \times \text{Score}(r)) $$
Where $\text{Score}(r)$ is calculated based on the quantity of expiring ingredients recipe $r$ consumes.

*Minimize Shopping List:*
$$ \text{Minimize} \sum_{i \in I_{all}} (\text{Required}(i) > \text{Available}(i)) $$

### Implementation Options & Trade-offs

Integrating an SMT solver into an Elixir application presents specific challenges. Below are the evaluated options:

#### Option A: Native Elixir Solvers (Limited)
*   **Libraries**: `Fixpoint` is the most notable constraint solver in Elixir.
*   **Pros**: Runs natively on the BEAM, no external dependencies.
*   **Cons**: `Fixpoint` is primarily a CSP (Constraint Satisfaction Problem) solver and may lack the advanced theories and performance optimizations of industrial SMT solvers like Z3 for complex arithmetic/optimization problems. It may be sufficient for simple versions of this feature but could hit performance walls.

#### Option B: External Solver via Ports/System Calls (Recommended for MVP)
*   **Approach**: Generate an SMT-LIB2 formatted file (standard SMT input format) and pipe it to a locally installed solver executable (e.g., `z3`, `cvc5`, `yices2`).
*   **Workflow**:
    1.  Elixir formats the problem into SMT-LIB2 syntax string.
    2.  `System.cmd("z3", ["-in"], input: smt_string)`
    3.  Elixir parses the standard output result.
*   **Pros**: Access to the full power of state-of-the-art solvers; SMT-LIB2 is a standard, allowing solver swapping.
*   **Cons**: Requires installing the solver binary on the server environment (Dockerfile update). Overhead of process spawning (usually negligible for this use case).

#### Option C: NIFs (Native Implemented Functions)
*   **Approach**: Use C/C++ bindings to link Z3 directly into the Erlang VM.
*   **Libraries**: There are no widely maintained, production-ready Z3 NIFs for Elixir currently.
*   **Pros**: Fastest performance.
*   **Cons**: High complexity to implement and maintain; a crash in the NIF crashes the entire VM. **Not recommended** for this feature due to stability risks.

#### Option D: External Microservice (Python/FastAPI)
*   **Approach**: A small Python service using the `z3-solver` pip package, exposing an HTTP endpoint.
*   **Pros**: Python has the best Z3 bindings (official). Separation of concerns.
*   **Cons**: Operational complexity of managing a sidecar service. Overkill for an initial feature.

### Recommendation
**Option B (System Calls to Z3)** is the most balanced approach. It offers the power of Z3 without the stability risks of NIFs or the operational overhead of a separate microservice. Elixir is excellent at text manipulation for generating SMT-LIB2 scripts.

## User Experience

### Dashboard Widget: "Waste Watch"
- Displays a "Optimize" button when high-priority items are expiring.
- Clicking it runs the solver and presents a "Rescue Plan": "Cook **Stir Fry** tonight to save your **Bell Peppers** and **Chicken**."

### Recipe Search Filter
- A toggle for "Minimize Shopping" which re-ranks recipes based on the solver's output for "fewest missing ingredients".

## Future Work
- **Meal Plan Generation**: Use the solver to generate a full week's meal plan that optimizes ingredient overlap (e.g., buy a pack of cilantro, use half on Mon, half on Wed).
- **Nutritional Balancing**: Add constraints for calories or macros (e.g., "Find dinner under 600kcal using these ingredients").
