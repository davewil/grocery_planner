import Sortable from "../../vendor/sortable"

/**
 * KanbanBoard hook for Power Mode drag-and-drop functionality.
 *
 * Enables dragging meals between days and meal slots using SortableJS.
 * Also handles dragging recipes from the sidebar to create new meals.
 */
export const KanbanBoard = {
  mounted() {
    this.sortables = [];
    this.draggedMeal = null;
    this.targetSlotOccupied = false;
    this.targetMealId = null;
    this.lastDragOverTarget = null;
    this.dragOverThrottle = null;

    this.initializeSortables();
    this.setupKeyboardShortcuts();

    // Re-initialize on LiveView updates
    this.handleEvent("meals_updated", () => {
      this.destroySortables();
      this.initializeSortables();
    });
  },

  destroyed() {
    this.destroySortables();
    this.removeKeyboardShortcuts();
  },

  updated() {
    // Re-initialize sortables when the DOM updates
    this.destroySortables();
    this.initializeSortables();
  },

  initializeSortables() {
    // Initialize sortable for each meal slot container
    const dropZones = this.el.querySelectorAll('[data-drop-zone]');

    dropZones.forEach(zone => {
      const sortable = new Sortable(zone, {
        group: 'meals',
        animation: 150,
        ghostClass: 'sortable-ghost',
        chosenClass: 'sortable-chosen',
        dragClass: 'rotate-1',
        forceFallback: true,
        fallbackTolerance: 3,

        // Only allow dragging meal cards, not empty slot buttons
        draggable: '[data-draggable="meal"]',

        // Handle to drag (optional, can be the whole card)
        // handle: '.drag-handle',

        onStart: (evt) => {
          const mealCard = evt.item;
          this.draggedMeal = {
            id: mealCard.dataset.mealId,
            sourceDate: mealCard.dataset.date,
            sourceMealType: mealCard.dataset.mealType
          };

          // Add visual feedback to all drop zones
          this.el.querySelectorAll('[data-drop-zone]').forEach(dz => {
            dz.classList.add('drop-zone-active');
          });
          document.body.style.cursor = 'grabbing';

          this.pushEvent("drag_start", {
            meal_id: this.draggedMeal.id,
            source_date: this.draggedMeal.sourceDate,
            source_meal_type: this.draggedMeal.sourceMealType
          });
        },

        onEnd: (evt) => {
          // Remove visual feedback
          this.el.querySelectorAll('[data-drop-zone]').forEach(dz => {
            dz.classList.remove('drop-zone-active', 'drop-zone-swap', 'bg-primary/10', 'ring-2', 'ring-primary/30', 'bg-warning/20', 'ring-warning/50');
          });
          document.body.style.cursor = '';

          // Clear drag over throttle
          if (this.dragOverThrottle) {
            clearTimeout(this.dragOverThrottle);
            this.dragOverThrottle = null;
          }

          this.pushEvent("drag_end", {});

          // Reset state
          this.draggedMeal = null;
          this.targetSlotOccupied = false;
          this.targetMealId = null;
          this.lastDragOverTarget = null;
        },

        onMove: (evt) => {
          const targetZone = evt.to;
          const targetDate = targetZone.dataset.date;
          const targetMealType = targetZone.dataset.mealType;

          // Check if target slot is occupied (has a meal card other than the one being dragged)
          const existingMeal = targetZone.querySelector('[data-draggable="meal"]');
          if (existingMeal && existingMeal !== evt.dragged) {
            this.targetSlotOccupied = true;
            this.targetMealId = existingMeal.dataset.mealId;

            // Visual indicator for swap
            targetZone.classList.add('drop-zone-swap');
            targetZone.classList.remove('drop-zone-active');
          } else {
            this.targetSlotOccupied = false;
            this.targetMealId = null;
            targetZone.classList.remove('drop-zone-swap');
          }

          // Push drag_over event with throttling for grocery delta calculation
          const targetKey = `${targetDate}-${targetMealType}`;
          if (this.lastDragOverTarget !== targetKey) {
            this.lastDragOverTarget = targetKey;

            // Clear existing throttle
            if (this.dragOverThrottle) {
              clearTimeout(this.dragOverThrottle);
            }

            // Throttle to avoid excessive calculations (300ms)
            this.dragOverThrottle = setTimeout(() => {
              this.pushEvent("drag_over", {
                target_date: targetDate,
                target_meal_type: targetMealType
              });
            }, 300);
          }

          return true; // Allow the move
        },

        onAdd: (evt) => {
          const mealCard = evt.item;
          const targetZone = evt.to;
          const targetDate = targetZone.dataset.date;
          const targetMealType = targetZone.dataset.mealType;

          // Check if this is a recipe being dragged from sidebar
          if (mealCard.dataset.draggable === 'recipe') {
            this.pushEvent("drop_recipe", {
              recipe_id: mealCard.dataset.recipeId,
              target_date: targetDate,
              target_meal_type: targetMealType
            });

            // Remove the cloned recipe card (sidebar recipes use clone)
            evt.item.remove();
            return;
          }

          // Handle meal card drop
          if (this.targetSlotOccupied && this.targetMealId) {
            // Trigger swap confirmation
            this.pushEvent("request_swap_confirmation", {
              dragged_meal_id: this.draggedMeal.id,
              target_meal_id: this.targetMealId,
              target_date: targetDate,
              target_meal_type: targetMealType
            });

            // Revert the DOM change - let LiveView handle it after confirmation
            evt.from.appendChild(evt.item);
          } else {
            // Normal move to empty slot
            this.pushEvent("drop_meal", {
              meal_id: this.draggedMeal.id,
              target_date: targetDate,
              target_meal_type: targetMealType
            });
          }
        }
      });

      this.sortables.push(sortable);
    });

    // Initialize sortable for recipe sidebar (if present)
    this.initializeSidebarSortable();
  },

  initializeSidebarSortable() {
    const sidebar = this.el.querySelector('[data-recipe-sidebar]');
    if (!sidebar) return;

    const recipeLists = sidebar.querySelectorAll('[data-recipe-list]');

    recipeLists.forEach(list => {
      const sortable = new Sortable(list, {
        group: {
          name: 'meals',
          pull: 'clone', // Clone recipes instead of moving
          put: false // Don't allow dropping meals back into sidebar
        },
        animation: 150,
        sort: false, // Don't allow reordering within sidebar
        draggable: '[data-draggable="recipe"]',
        ghostClass: 'sortable-ghost',
        forceFallback: true,
        fallbackTolerance: 3,

        onStart: (evt) => {
          this.pushEvent("sidebar_drag_start", {
            recipe_id: evt.item.dataset.recipeId
          });
        },

        onEnd: (evt) => {
          this.pushEvent("sidebar_drag_end", {});
        }
      });

      this.sortables.push(sortable);
    });
  },

  destroySortables() {
    this.sortables.forEach(sortable => {
      if (sortable && sortable.destroy) {
        sortable.destroy();
      }
    });
    this.sortables = [];
  },

  setupKeyboardShortcuts() {
    this.keydownHandler = (e) => {
      // Ignore if typing in an input
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
        return;
      }

      // Ctrl/Cmd + Z = Undo
      if ((e.ctrlKey || e.metaKey) && e.key === 'z' && !e.shiftKey) {
        e.preventDefault();
        this.pushEvent("undo", {});
      }

      // Ctrl/Cmd + Shift + Z = Redo
      if ((e.ctrlKey || e.metaKey) && e.key === 'z' && e.shiftKey) {
        e.preventDefault();
        this.pushEvent("redo", {});
      }

      // Delete / Backspace = Delete selected meals
      if (e.key === 'Delete' || e.key === 'Backspace') {
        e.preventDefault();
        this.pushEvent("delete_selected", {});
      }

      // Escape = Clear selection
      if (e.key === 'Escape') {
        e.preventDefault();
        this.pushEvent("clear_selection", {});
      }

      // Ctrl/Cmd + A = Select all visible
      if ((e.ctrlKey || e.metaKey) && e.key === 'a') {
        e.preventDefault();
        this.pushEvent("select_all", {});
      }

      // Arrow keys for week navigation
      if (e.key === 'ArrowLeft' && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        this.pushEvent("prev_week", {});
      }
      if (e.key === 'ArrowRight' && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        this.pushEvent("next_week", {});
      }
    };

    document.addEventListener('keydown', this.keydownHandler);
  },

  removeKeyboardShortcuts() {
    if (this.keydownHandler) {
      document.removeEventListener('keydown', this.keydownHandler);
    }
  }
};
