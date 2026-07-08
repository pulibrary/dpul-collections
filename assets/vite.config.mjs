import { defineConfig } from "vite"
import { svelte } from "@sveltejs/vite-plugin-svelte"
import liveSveltePlugin from "live_svelte/vitePlugin"
// With Tailwind: add this import
import tailwindcss from "@tailwindcss/vite"

export default defineConfig({
  server: {
    host: "127.0.0.1",
    port: 5173,
    strictPort: true,
    cors: { origin: "http://localhost:4000" },
  },
  optimizeDeps: {
    include: ["live_svelte", "phoenix", "phoenix_html", "phoenix_live_view"],
  },
  ssr: { noExternal: process.env.NODE_ENV === "production" ? true : undefined },
  build: {
    manifest: false,
    ssrManifest: false,
    rollupOptions: { input: ["js/app.js", "css/app.css"] },
    outDir: "../priv/static/",
    emptyOutDir: false
  },
  // Required for Phoenix 1.8+ colocated JS hooks
  resolve: {
    alias: {
      "phoenix-colocated": `${process.env.MIX_BUILD_PATH}/phoenix-colocated`,
    },
  },
  plugins: [
    tailwindcss(), // With Tailwind: include this; remove if not using Tailwind
    svelte({ compilerOptions: { css: "injected" } }),
    liveSveltePlugin({ entrypoint: "./js/server.js" }),
  ],
})
