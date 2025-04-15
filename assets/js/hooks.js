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

export default Hooks;