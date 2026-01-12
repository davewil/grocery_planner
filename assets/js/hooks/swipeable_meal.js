export const SwipeableMeal = {
  mounted() {
    this.startX = 0;
    this.currentX = 0;
    this.threshold = 80;
    this.el.style.touchAction = 'pan-y'; // Allow vertical scrolling, handle horizontal manually

    this.el.addEventListener('touchstart', (e) => this.handleTouchStart(e));
    this.el.addEventListener('touchmove', (e) => this.handleTouchMove(e));
    this.el.addEventListener('touchend', (e) => this.handleTouchEnd(e));
  },

  handleTouchStart(e) {
    this.startX = e.touches[0].clientX;
    this.el.style.transition = 'none';
  },

  handleTouchMove(e) {
    this.currentX = e.touches[0].clientX;
    const diff = this.currentX - this.startX;

    // Only handle horizontal swipes
    if (Math.abs(diff) < 10) return;

    // Limit swipe distance for visual feedback
    // Resistance effect
    const resistance = 0.5;
    const limitedDiff = diff * resistance;
    
    // Clamp
    const clampedDiff = Math.max(-this.threshold * 1.5, Math.min(this.threshold * 1.5, limitedDiff));

    this.el.style.transform = `translateX(${clampedDiff}px)`;
    
    // Show/hide action backgrounds based on direction
    const leftAction = this.el.querySelector('.swipe-action-left');
    const rightAction = this.el.querySelector('.swipe-action-right');
    
    if (diff < 0) { // Swiping left (Delete/Clear)
       if (leftAction) leftAction.style.opacity = Math.min(1, Math.abs(diff) / this.threshold);
       if (rightAction) rightAction.style.opacity = 0;
    } else { // Swiping right (Swap)
       if (rightAction) rightAction.style.opacity = Math.min(1, Math.abs(diff) / this.threshold);
       if (leftAction) leftAction.style.opacity = 0;
    }
  },

  handleTouchEnd(e) {
    const diff = this.currentX - this.startX;
    this.el.style.transition = 'transform 0.3s cubic-bezier(0.4, 0.0, 0.2, 1)';

    if (diff < -this.threshold) {
      // Swipe left - delete
      // Animate out
      this.el.style.transform = `translateX(-100%)`;
      // Wait for animation then push event
      setTimeout(() => {
        this.pushEvent("remove_meal", { id: this.el.dataset.mealId });
        // Reset transform in case the removal fails or we just refresh the list
        setTimeout(() => { this.el.style.transform = ''; }, 200);
      }, 300);
    } else if (diff > this.threshold) {
      // Swipe right - swap
      // Bounce back
      this.el.style.transform = '';
      this.pushEvent("swap_meal", { id: this.el.dataset.mealId });
    } else {
      // Reset
      this.el.style.transform = '';
    }
    
    this.startX = 0;
    this.currentX = 0;
  }
};
