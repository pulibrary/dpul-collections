// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

// const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/dpul_collections_web.ex",
    "../lib/dpul_collections_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
      }
    },
  },
  plugins: [
  ]
}
