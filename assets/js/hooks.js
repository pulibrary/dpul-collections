let Hooks = {};

Hooks.ToolbarHook = {
  mounted() {

    const sideMenu = document.getElementById("sticky-tools");

    this.observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) {
          sideMenu.classList.remove('opacity-0', 'pointer-events-none');
        } else if (entry.isIntersecting) {
          sideMenu.classList.add('opacity-0', 'pointer-events-none');
        }
      });
    }, {
      root: null,
      rootMargin: '0px',
      threshold: [0]
    });
    this.observer.observe(this.el);
  },
  updated(){
    console.log("updated")
  }
};

export default Hooks;