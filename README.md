[![Hex.pm](https://img.shields.io/hexpm/v/live_react.svg)](https://hex.pm/packages/live_react)
[![Hexdocs.pm](https://img.shields.io/badge/docs-hexdocs.pm-purple)](https://hexdocs.pm/live_react)
[![GitHub](https://img.shields.io/github/stars/mrdotb/live_react?style=social)](https://github.com/mrdotb/live_vue)

# LiveReact

React inside Phoenix LiveView.

## Features

- ⚡ **End-To-End Reactivity** with LiveView
- 🦄 **Tailwind** Support
- 💀 **Dead View** Support

## Resources

- [Demo](https://live-react-examples.fly.dev/simple)
- [HexDocs](https://hexdocs.pm/live_react)
- [HexPackage](https://hex.pm/packages/live_react)
- [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view)

## Why LiveReact

Phoenix LiveView enables rich, real-time user experiences with server-rendered HTML.
It works by communicating any state changes through a websocket and updating the DOM in realtime.
You can get a really good user experience without ever needing to write any client side code.

LiveReact builds on top of Phoenix LiveView to allow for easy client side state management while still allowing for communication over the websocket.

## Installation

1. Add `live_react` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:live_react, "~> 0.1.0"}
  ]
end
```

2. Adjust the `setup` in `mix.exs`:

- For Linux/MacOs

```elixir
defp aliases do
    [
      setup: ["deps.get", "assets.setup", "npm install --prefix assets", "assets.build"],
    ]
end
```

- For Windows

```elixir
defp aliases do
    [
      setup: ["deps.get", "assets.setup", "cmd --cd assets npm install", "assets.build"],
    ]
end
```

3. Run the following in your terminal

```bash
mix deps.get
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

5. Create a package.json file at `assets/package.json`

```json
{
  "dependencies": {
    "@mrdotb/live-react": "^0.1.0",
    "phoenix": "file:../deps/phoenix",
    "phoenix_html": "file:../deps/phoenix_html",
    "phoenix_live_view": "file:../deps/phoenix_live_view",
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  }
}
```

6. Create a `react` directory inside `assets` and add a `index.js` file

```javascript
// import and export the react components you want to use in your LiveView
// ex: import { Simple } from "./simple";

// ex: export default { Simple };
export default {};
```

7. Add the following to your `assets/js/app.js` file

```javascript
...
import components from "../react";
import { getHooks } from "live_react";

const hooks = {
  ...getHooks(components),
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: hooks, // <-- pass the hooks
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

## Examples

Check out the [demo website](https://live-react-examples.fly.dev/simple) on fly.io to see some examples of what you can do with LiveReact.

## Credits

I was inspired by the following libraries:
- [LiveVue](https://github.com/Valian/live_vue)
- [LiveSvelte](https://github.com/woutdp/live_svelte)

I had a need for a similar library for React and so I created LiveReact 👍
