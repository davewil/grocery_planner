export const SwipeableDay = {
  mounted() {
    this.startX = 0;
    this.startY = 0;

    this.threshold = 60;
    this.restraint = 90;

    this.el.addEventListener("touchstart", (e) => this.handleTouchStart(e), { passive: true });
    this.el.addEventListener("touchend", (e) => this.handleTouchEnd(e), { passive: true });
  },

  handleTouchStart(e) {
    const t = e.touches[0];
    this.startX = t.clientX;
    this.startY = t.clientY;
  },

  handleTouchEnd(e) {
    const t = e.changedTouches[0];
    const diffX = t.clientX - this.startX;
    const diffY = t.clientY - this.startY;

    if (Math.abs(diffX) > this.threshold && Math.abs(diffY) < this.restraint) {
      if (diffX > 0) {
        this.pushEvent("focus_prev_day", {});
      } else {
        this.pushEvent("focus_next_day", {});
      }
    }
  }
};
