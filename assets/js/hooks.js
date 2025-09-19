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
      // If the user hits "escape" then JS closes the modal, we still want
      // after-close to render.
      this.js().exec(this.el.getAttribute('dcjs-after-close'))
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

    function getLastVisibleImg(container) {
      const allImages = container.querySelectorAll('img')
      let lastImg = null

      allImages.forEach(el => {
        if (!isElementHiddenByOverflow(el, container)) {
          lastImg = el
        }
      })
      console.log(lastImg)
      return lastImg
    }

    function isElementHiddenByOverflow(element, container) {
      const elementRect = element.getBoundingClientRect()
      const containerRect = container.getBoundingClientRect()
      // Check if the element is outside the container boundaries
      return (
        elementRect.bottom >= containerRect.bottom
      )
    }

    // Get Elements
    let elID = this.el.getAttribute("data-id")
    // subtract large thumbnail from total file count; it has separate layout
    let elFilecount = this.el.getAttribute("data-filecount") - 1
    let fileCountLabelEl = window.document.getElementById('filecount-'+elID)
    let containerEl = window.document.getElementById('item-metadata-'+elID)

    // Handle Resize
    this.handleResize = () => {
      if(showPageCount(containerEl, elFilecount) && fileCountLabelEl !== null){
        let lastImg = getLastVisibleImg(containerEl)
        console.log(lastImg)
        lastImg.parentElement.append(fileCountLabelEl)
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

Hooks.ResponsivePills = {
  mounted() {
    this.totalCount = this.el.querySelectorAll('.pill-item').length
    this.isExpanded = false
    this.moreButton = this.el.querySelector('.more-button button')
    this.lessButton = this.el.querySelector('.less-button button')
    this.setupToggleListeners()
    this.calculateVisibleItems()
    // Handle resize with debouncing
    this.resizeTimeout = null
    this.boundResizeListener = () => {
      clearTimeout(this.resizeTimeout)
      this.resizeTimeout = setTimeout(() => {
        if (!this.isExpanded) {
          this.calculateVisibleItems()
        }
      }, 250)
    }
    window.addEventListener("resize", this.boundResizeListener)
  },

  setupToggleListeners() {
    this.moreButton.addEventListener('click', () => this.expand())
    this.lessButton.addEventListener('click', () => this.collapse())
  },

  expand() {
    this.isExpanded = true
    const ul = this.el.querySelector('.group')
    ul.classList.add('expanded')
  },

  collapse() {
    this.isExpanded = false
    const ul = this.el.querySelector('.group')
    ul.classList.add('expanded')

    // Recalculate visible items for current viewport
    this.calculateVisibleItems()
  },

  calculateVisibleItems() {
    // Don't recalculate if expanded
    if (this.isExpanded) return

    const ul = this.el.querySelector('.group')
    // Temporarily show all items and remove constraints to measure
    ul.classList.add("expanded")
    const allPillItems = this.el.querySelectorAll('.pill-item')

    // Temporarily show all pills for measurement
    allPillItems.forEach(item => item.classList.remove('hidden'))

    // Get container width
    const containerWidth = ul.offsetWidth
    let currentWidth = 0
    let visibleCount = 0

    // Gap between pills is 8px
    const gap = 8

    // Reserve space for the more button
    // The more button is invisible rather than hidden, so we can get its
    // height/width.
    const moreButtonWidth = this.moreButton.offsetWidth + gap

    // Calculate how many items fit on one line
    for (let i = 0; i < allPillItems.length; i++) {
      const itemWidth = allPillItems[i].offsetWidth + gap

      // Check if this item plus the more button would fit
      if (currentWidth + itemWidth + moreButtonWidth <= containerWidth) {
        currentWidth += itemWidth
        visibleCount++
      } else {
        break
      }
    }
    // Hide every pill that doesn't fit so that "more" will slide into place.
    Array.from(allPillItems).slice(visibleCount).forEach(item => item.classList.add('hidden'))

    // Remove expand so the pills will contract again, it was only temporary to get widths.
    ul.classList.remove("expanded")

    // Update the more count
    const moreCountSpan = this.el.querySelector('.more-count')
    const remainingCount = this.totalCount - visibleCount
    moreCountSpan.textContent = remainingCount
    if (remainingCount == 0) {
      this.moreButton.parentElement.classList.add("invisible")
    } else {
      this.moreButton.parentElement.classList.remove("invisible")
    }
  }
}

export default Hooks;
