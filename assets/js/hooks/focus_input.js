export const FocusInput = {
  mounted() {
    this.el.focus();
    // Move cursor to end
    const val = this.el.value;
    this.el.value = '';
    this.el.value = val;
  }
};
