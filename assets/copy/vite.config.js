import path from "path";
import { defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";

import react from "@vitejs/plugin-react";
import liveReactPlugin from "live_react/vite-plugin";

// https://vitejs.dev/config/
export default defineConfig(({ command }) => {
  const isDev = command !== "build";

  return {
    base: isDev ? undefined : "/assets",
    publicDir: "static",
    plugins: [react(), liveReactPlugin(), tailwindcss()],
    ssr: {
      external: [
        "react",
        "react-dom",
        "react-dom/server",
        "react/jsx-runtime",
        "react/jsx-dev-runtime",
      ],
      noExternal: ["live_react"],
    },
    resolve: {
      alias: {
        "@": path.resolve(__dirname, "./react-components"),
      },
      dedupe: ["react", "react-dom"],
    },
    optimizeDeps: {
      // these packages are loaded as file:../deps/<name> imports
      // so they're not optimized for development by vite by default
      // we want to enable it for better DX
      // more https://vitejs.dev/guide/dep-pre-bundling#monorepos-and-linked-dependencies
      include: ["live_react", "phoenix", "phoenix_html", "phoenix_live_view"],
    },
    build: {
      commonjsOptions: { transformMixedEsModules: true },
      target: "es2020",
      outDir: "../priv/static/assets", // emit assets to priv/static/assets
      emptyOutDir: true,
      sourcemap: isDev, // enable source map in dev build
      manifest: false, // do not generate manifest.json
      rollupOptions: {
        input: {
          app: path.resolve(__dirname, "./js/app.js"),
        },
        output: {
          // remove hashes to match phoenix way of handling assets
          entryFileNames: "[name].js",
          chunkFileNames: "[name].js",
          assetFileNames: "[name][extname]",
        },
      },
    },
  };
});
