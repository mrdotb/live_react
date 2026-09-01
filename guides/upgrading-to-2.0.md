# Upgrading to 2.0

LiveReact 2.0 sends prop changes as patches instead of resending the whole
payload on every update. Making that safe required one breaking change:
structs passed as props must now say which of their fields may be sent to the
browser.

## 1. Bump the dependency

```elixir
def deps do
  [
    {:live_react, "~> 2.0"}
  ]
end
```

The JavaScript ships inside the Hex package, so refresh it too:

```bash
mix deps.get
npm install --prefix assets
```

## 2. Derive `LiveReact.Encoder` for struct props

Props used to be encoded with `Jason.Encoder`. They are now encoded with
`LiveReact.Encoder`, which converts structs to maps so they can be diffed
field by field.

If you pass a struct as a prop and it has no implementation, rendering raises a
`Protocol.UndefinedError` naming the struct. The fix is a `@derive`:

```elixir
defmodule User do
  @derive LiveReact.Encoder
  defstruct [:id, :name, :email]
end
```

Every field except `:__struct__` is encoded by default. Restrict that with
`:only` or `:except` — worth doing for anything holding secrets:

```elixir
defmodule User do
  @derive {LiveReact.Encoder, except: [:password_hash, :session_token]}
  defstruct [:id, :name, :email, :password_hash, :session_token]
end
```

For a struct you do not own, derive it from outside the module:

```elixir
# lib/my_app/encoders.ex
Protocol.derive(LiveReact.Encoder, SomeLibrary.Struct, only: [:id, :label])
```

Or implement the protocol yourself when the shape needs work:

```elixir
defimpl LiveReact.Encoder, for: Money do
  def encode(money, opts) do
    LiveReact.Encoder.encode(%{amount: money.amount, currency: money.currency}, opts)
  end
end
```

Plain maps, lists, strings, numbers and atoms are unaffected — nothing to do.
Neither are the structs LiveReact already implements: `Date`, `Time`,
`NaiveDateTime`, `DateTime`, `Phoenix.HTML.Form`,
`Phoenix.LiveView.AsyncResult`, `Phoenix.LiveView.UploadConfig` and
`Phoenix.LiveView.UploadEntry`. See
[Props diffing and streams](props-diffing.md#built-in-implementations) for the
shapes they produce.

### Why not `Jason.Encoder`?

`Jason.Encoder` produces a JSON string. Diffing needs the intermediate map so
it can compare field by field, which is what `LiveReact.Encoder` returns. The
explicit-implementation requirement is deliberate: it keeps a struct from
silently shipping fields nobody intended to expose.

## 3. Check components that update frequently

Diffing is on by default and needs no code changes. If a component misbehaves
after the upgrade, turn diffing off for it and compare:

```heex
<.react name="Chart" data={@points} diff={false} />
```

That restores 1.x behavior for that component. Globally:

```elixir
config :live_react, enable_props_diff: false
```

If you find a case where diffing is wrong, please
[open an issue](https://github.com/mrdotb/live_react/issues) — the goal is for
`diff={false}` to be a workaround rather than a fixture.

## What else is new

Stream assigns can be passed straight to a component, without serializing them
yourself:

```heex
<.react name="Messages" messages={@streams.messages} />
```

See [Props diffing and streams](props-diffing.md#streams).
