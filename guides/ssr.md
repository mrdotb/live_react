# Server Side Rendering (SSR)

_Disclaimer_ SSR is not a simple topic and there is a lot of issue than can arise depending on what React components you are using. This is a simple implementation that works for the components and library I have tested.

## Project setup

SSR requires Node.js to render the javascript on server side. Add `nodejs` to your mix file.

```elixir
defp deps do
  [
    {:nodejs, "~> 3.1"},
    ...
  ]
end
```

Add NodeJs.Supervisor to your `application.ex`

```elixir
def start(_type, _args) do
  children = [
    ...
    {NodeJS.Supervisor, [path: LiveReact.SSR.NodeJS.server_path(), pool_size: 4]},
  ]
end
```

A server file is needed copy the `server.mjs` file into your assets

```bash
curl https://raw.githubusercontent.com/mrdotb/live-react/main/assets/copy/server.mjs > assets/server.mjs
```

Edit `config/config.exs` to add a second esbuild process

```elixir
config :esbuild,
  version: "0.17.11",
  client: [
    args: ~w(
        js/app.js
        --chunk-names=[name]-[hash]
        --splitting
        --format=esm
        --bundle
        --target=es2020
        --main-fields=module,main,exports
        --outdir=../priv/static/assets
        --external:/fonts/* --external:/images/*
      ),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ],
  server: [
    args: ~w(
      js/server.mjs
      --bundle
      --platform=node
      --target=node19
      --outdir=../priv/react
    ),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]
```

In your `config/dev.exs` edit the watchers to include a watch on the server esbuild

```elixir
config :live_react_examples, LiveReactExamplesWeb.Endpoint,
  watchers: [
    client_esbuild: {Esbuild, :install_and_run, [
      :client, ~w(--sourcemap=inline --watch),
    ]},
    server_esbuild: {Esbuild, :install_and_run, [
      :server, ~w(--sourcemap=inline --watch),
    ]}
  ]
```

Lastly edit the aliases in `mix.exs`

```elixir
defp aliases do
[
  setup: ["deps.get", "assets.setup", "cmd npm install --prefix assets", "assets.build"],
  "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
  "assets.build": ["tailwind live_react_examples", "esbuild client", "esbuild server"],
  "assets.deploy": [
    "tailwind live_react_examples --minify",
    "esbuild client --minify",
    "esbuild server --minify",
    "phx.digest"
  ]
]
end
```

For deployment follow the [SSR deployment guide](/guides/deployment.md#with-ssr)
