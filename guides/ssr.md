# Server Side Rendering (SSR)

_Disclaimer_ SSR for React is not a simple topic and there is a lot of issue than can arise depending on what React components you are using. It also consume more ressource since a nodejs worker is needed for the rendering. This is a simple implementation that works for the components and library I have tested.

## Project setup

⚠️ **Warning:** Server-side rendering (SSR) requires a Node.js worker. With a `pool_size` of 1 and the Phoenix app, you need at least **512MiB** of memory. Otherwise, the instance may experience **out-of-memory (OOM)** errors or severe slowness.

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

Add a config entry to your `config/prod.exs`

```elixir
config :live_react,
  ssr_module: LiveReact.SSR.NodeJS,
  ssr: true
```

For complete deployment follow the [SSR deployment guide](/guides/deployment.md#with-ssr)
