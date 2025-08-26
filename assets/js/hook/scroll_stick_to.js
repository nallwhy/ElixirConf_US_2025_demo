export default {
  mounted() {
    const { parentId, scrollTo } = this.el.dataset
    this.scrollTo = scrollTo

    this.setInitScrollByParent(parentId)
  },
  updated() {
    this.scroll()
  },
  setInitScrollByParent(parentId) {
    if (parentId) {
      const parentEl = document.getElementById(parentId)

      this.observer = new MutationObserver(() => {
        if (window.getComputedStyle(parentEl).display !== 'none') {
          this.scroll(false)
          this.observer.disconnect()
        }
      })

      this.observer.observe(parentEl, {
        attributes: true,
        attributeFilter: ["style", "class"]
      })
    }

  },
  scroll(check_scroll = true) {
    if (check_scroll) {
      switch (this.scrollTo) {
        case "top":
          // Not implemented
          break;
        case "bottom":
          const pos = this.el.scrollHeight - this.el.clientHeight - this.el.scrollTop
          if (pos > this.el.clientHeight * 0.3) {
            return;
          }
        default:
          break;
      }
    }

    switch (this.scrollTo) {
      case "top":
        this.el.scrollTo(this.el.scrollLeft, 0);
        break;
      case "bottom":
        this.el.scrollTo(this.el.scrollLeft, this.el.scrollHeight);
        break;
      default:
        console.error("Invalid scroll target:", this.to);
    }
  },
};
