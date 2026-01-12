export const LongPress = {
  mounted() {
    this.timer = null;
    this.duration = 600; // ms

    this.el.addEventListener('touchstart', (e) => this.handleStart(e));
    this.el.addEventListener('touchend', (e) => this.handleEnd(e));
    this.el.addEventListener('mousedown', (e) => this.handleStart(e));
    this.el.addEventListener('mouseup', (e) => this.handleEnd(e));
    this.el.addEventListener('mouseleave', (e) => this.handleEnd(e));
  },

  handleStart(e) {
    this.timer = setTimeout(() => {
      this.pushEventTo(this.el, "long_press", { id: this.el.dataset.id });
      if (window.navigator.vibrate) {
        window.navigator.vibrate(50);
      }
    }, this.duration);
  },

  handleEnd(e) {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
  }
};
