export const SwipeableWeek = {
  mounted() {
    this.startX = 0;
    this.currentX = 0;
    this.threshold = 50;
    // Allow vertical scroll, but we want to capture horizontal for prev/next week
    // But wait, the week strip itself might be scrollable?
    // If the week strip is scrollable (overflow-x-auto), we shouldn't hijack swipe unless it's at the edge or if it's a pager.
    // The spec layout shows [M] [T] [W]... all visible? Or scrollable?
    // "Swipeable Week Strip" usually implies swiping the whole strip to go to prev/next week.
    
    this.el.addEventListener('touchstart', (e) => this.handleTouchStart(e));
    this.el.addEventListener('touchend', (e) => this.handleTouchEnd(e));
  },

  handleTouchStart(e) {
    this.startX = e.touches[0].clientX;
  },

  handleTouchEnd(e) {
    this.currentX = e.changedTouches[0].clientX;
    const diff = this.currentX - this.startX;

    if (Math.abs(diff) > this.threshold) {
      if (diff > 0) {
        // Swipe Right -> Previous Week
        this.pushEvent("prev_week", {});
      } else {
        // Swipe Left -> Next Week
        this.pushEvent("next_week", {});
      }
    }
  }
};
