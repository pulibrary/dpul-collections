let Hooks = {};

Hooks.ToolbarHook = {
  mounted() {
    this.observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) {
          this.pushEvent("show_stickytools", {})
        } else if (entry.isIntersecting) {
          this.pushEvent("hide_stickytools", {})
        }
      });
    }, {
      root: null,
      rootMargin: '0px',
      threshold: [0]
    });
    this.observer.observe(this.el);
  }
};

// Scrolls to the top of the page when an element is mounted. Usually
// used for slide ins updated via patch.
Hooks.ScrollTop = {
  mounted() {
    window.scrollTo(0,0)
  }
}

export default Hooks;
