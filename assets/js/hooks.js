import LiveReact from "phoenix_live_react"
import {hooks as colocatedHooks} from "phoenix-colocated/dpul_collections"
let Hooks = { LiveReact, colocatedHooks };

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

Hooks.Dialog = {
  mounted() {
    this.el.addEventListener('dpulc:closeDialog', (e) =>  {
      this.el.close()
    })
    this.el.addEventListener('dpulc:showDialog', (e) =>  {
      this.el.showModal()
    })
    this.el.addEventListener('close', (e) => {
      this.js().exec(this.el.getAttribute('phx-after-close'))
    })
  }
}

// Scrolls to the top of the page when an element is mounted. Usually
// used for slide ins updated via patch.
Hooks.ScrollTop = {
  mounted() {
    window.scrollTo(0,0)
  }
}

Hooks.ShowPageCount = {
  mounted() {
    function showPageCount(container, totalFiles) {
      const allImages = container.querySelectorAll('img')
      let hiddenCount = 0
      let containerFileCount = 0

      allImages.forEach(el => {
        containerFileCount++
        if (isElementHiddenByOverflow(el, container)) {
          hiddenCount++
        }
      })

      if ((totalFiles == containerFileCount && hiddenCount == 0)) {
        return false
      } 
      return true
    }

    function isElementHiddenByOverflow(element, container) {
      const elementRect = element.getBoundingClientRect()
      const containerRect = container.getBoundingClientRect()
      // Check if the element is outside the container boundaries
      // There is a 92 px offset to account for
      return (
        elementRect.top >= containerRect.bottom - 92
      )
    }

    // Get Elements
    let elID = this.el.getAttribute("data-id")
    let elFilecount = this.el.getAttribute("data-filecount")
    let fileCountLabelEl = window.document.getElementById('filecount-'+elID)
    let containerEl = window.document.getElementById('item-'+elID)

    // Handle Resize
    this.handleResize = () => {
      if(showPageCount(containerEl, elFilecount) && fileCountLabelEl !== null){
        fileCountLabelEl.style.display = "block"
      } else {
        fileCountLabelEl.style.display = "none"
      }
    }

    // Add event listener to call on resize (debounce for performance)
    let resizeTimeout
    this.boundResizeListener = () => {
      clearTimeout(resizeTimeout)
      resizeTimeout = setTimeout(() => {
        this.handleResize()
      }, 200);
    };
    window.addEventListener("resize", this.boundResizeListener);

    // Call on initial mount
    this.handleResize()
  },

  destroyed() {
    // Clean up the event listener when the hook is destroyed
    window.removeEventListener("resize", this.handleResize)
  }
}

export default Hooks;
