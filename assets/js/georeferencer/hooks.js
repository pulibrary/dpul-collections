// LiveView hooks for the georeferencer's pages. Each loads its page's code (OpenCV.js, the ONNX
// runtime, Leaflet) only when that page mounts, so the rest of the site never downloads it.
const lazy = (load, name) => ({
  mounted() {
    load().then((module) => {
      if (this.gone) return;
      // LiveView copies this object's callbacks onto the hook instance, so don't copy the
      // instance: hand the implementation just the element and the event functions
      this.impl = Object.create(module[name]);
      this.impl.el = this.el;
      this.impl.pushEvent = this.pushEvent.bind(this);
      this.impl.handleEvent = this.handleEvent.bind(this);
      this.impl.mounted();
    }).catch((e) => console.error(`${name} failed to load`, e));
  },
  destroyed() {
    this.gone = true;
    if (this.impl) this.impl.destroyed();
  },
});

export const Georeferencer = lazy(() => import("./index"), "Georeferencer");
export const GeorefVolunteer = lazy(() => import("./volunteer"), "GeorefVolunteer");
