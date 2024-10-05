# Installation

LiveReact replaces `hex esbuild` with [Vite](https://vite.dev/) for both client side code and SSR to achieve a better development experience. Why ?

- Vite provides a best-in-class Hot-Reload functionality and offers [many benefits](https://vitejs.dev/guide/why#why-vite) not present in esbuild
- `hex esbuild` package doesn't support plugins, while it's possible to do ssr with `hex esbuild` (check [v0.2.0-rc-0](https://github.com/mrdotb/live_react/tree/v0.2.0-rc.0)) the SSR in development is broken.
- the integration to react and ssr is more documented with Vite

In production, we'll use [elixir-nodejs](https://github.com/revelrylabs/elixir-nodejs) for SSR. If you don't need SSR, you can disable it with one line of code. TypeScript will be supported as well.

## Steps

0. install nodejs (I recommend [mise](https://mise.jdx.dev/))

1. Add `live_react` to your list of dependencies in `mix.exs` and run `mix deps.get`

```elixir
def deps do
  [
    {:live_react, "~> 0.3.0-rc.0"}
  ]
end
```

2. Add a config entry to your `config/dev.exs`

```elixir
config :live_react,
  vite_host: "http://localhost:5173",
  ssr_module: LiveReact.SSR.ViteJS,
  ssr: true
```

3. Add a config entry to your `config/prod.exs`

```elixir
config :live_react,
  ssr_module: LiveReact.SSR.NodeJS,
  ssr: true # or false if you don't want SSR in production
```

4. Add `import LiveReact` in `html_helpers/0` inside `/lib/<app_name>_web.ex` like so:

```elixir
# /lib/<app_name>_web.ex

defp html_helpers do
  quote do

    # ...

    import LiveReact # <-- Add this line

    # ...

  end
end
```

5. LiveReact comes with a handy mix task to setup all the required files. It won't alter any files you already have in your project, you need to adjust them on your own by looking at the [sources](https://github.com/mrdotb/live_react/tree/main/assets/js/copy). Additional instructions how to adjust `package.json` can be found at the end of this page.

It will create:

- `package.json`
- vite, typescript and postcss configs
- server entrypoint
- react components root

6. Run the following in your terminal

```bash
mix deps.get
mix live_react.setup
npm install --prefix assets
```

7. Add the following to your `assets/js/app.js` file

```javascript
...
import "vite/modulepreload-polyfill" // required vite polyfill
import topbar from "topbar" // instead of ../vendor/topbar
import { getHooks } from  "live-react";
import components from "../react";
import "../css/app.css" // the css file is handled by vite

const hooks = {
  // ... your other hooks
  ...getHooks(components),
};

...

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: hooks, // <- pass the hooks
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
});
...
```

7. For tailwind support, make some addition to `content` in the `assets/tailwind.config.js` file

```javascript
content: [
  ...
    "./react/**/*.jsx", // <- if you are using jsx
    "./react/**/*.tsx" // <- if you are using tsx
],

```

8. Let's update `root.html.heex` to use Vite files in development. There's a handy wrapper for it.

```html
<LiveReact.Reload.vite_assets assets={["/js/app.js", "/css/app.css"]}>
  <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
  <script type="module" phx-track-static type="text/javascript" src={~p"/assets/app.js"}>
  </script>
</LiveReact.Reload.vite_assets>
```

9. Update `mix.exs` aliases and remove `tailwind` and `esbuild` packages

```elixir
defp aliases do
[
  setup: ["deps.get", "assets.setup", "assets.build"],
  "assets.setup": ["cmd --cd assets npm install"],
  "assets.build": [
    "cmd --cd assets npm run build",
    "cmd --cd assets npm run build-server"
  ],
  "assets.deploy": [
    "cmd --cd assets npm run build",
    "cmd --cd assets npm run build-server",
    "phx.digest"
  ]
]
end

defp deps do
  [
    # remove these lines, we don't need esbuild or tailwind here anymore
    # {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
    # {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
  ]
end
```

10. Remove esbuild and tailwind config from `config/config.exs`

11. Update watchers in `config/dev.exs` to look like this

```elixir
config :my_app, MyAppWeb.Endpoint,
  # ...
  watchers: [
    npm: ["run", "dev", cd: Path.expand("../assets", __DIR__)]
  ]
```

12. To make SSR working with `LiveReact.SSR.NodeJS` in production, you have to add this entry to your `application.ex` supervision tree to run the NodeJS server

```elixir
children = [
  ...
  {NodeJS.Supervisor, [path: LiveReact.SSR.NodeJS.server_path(), pool_size: 4]},
  # note Adjust the pool_size depending of the machine
]
```

13. Confirm everything is working by rendering the default React component anywhere in your Dead or Live Views

```elixir
<.react name="Simple" />
```

14. (Optional) enable [stateful hot reload](https://twitter.com/jskalc/status/1788308446007132509) of phoenix LiveViews - it allows for stateful reload across the whole stack 🤯. Just adjust your `dev.exs` to look like this - add `notify` section and remove `live|components` from patterns.

```elixir
# Watch static and templates for browser reloading.
config :my_app, MyAppWeb.Endpoint,
  live_reload: [
    notify: [
      live_view: [
        ~r"lib/my_app_web/core_components.ex$",
        ~r"lib/my_app_web/(live|components)/.*(ex|heex)$"
      ]
    ],
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/my_app_web/controllers/.*(ex|heex)$"
    ]
  ]
```

Profit! 💸

## Adjusting your own package.json

Install these packages

```bash
cd assets

# vite
npm install -D vite @vitejs/plugin-react

# tailwind
npm install -D tailwindcss autoprefixer postcss @tailwindcss/forms

# typescript
npm install -D typescript @types/react @types/react-dom

# runtime dependencies
npm install --save vue topbar ../deps/live_react ../deps/phoenix ../deps/phoenix_html ../deps/phoenix_live_view

# remove topbar from vendor, since we'll use it from node_modules
rm vendor/topbar.js
```

and add these scripts used by watcher and `mix assets.build` command

```json
{
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite --host -l warn",
    "build": "tsc && vite build",
    "build-server": "tsc && vite build --ssr js/server.js --out-dir ../priv/react --minify esbuild && echo '{\"type\": \"module\" } ' > ../priv/react/package.json"
  }
}
```
