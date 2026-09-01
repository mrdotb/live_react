# Props Diffing and Streams

Before 2.0, every LiveView update re-sent the complete props payload for a
component. A component holding a large list re-serialized that whole list
whenever any of its props changed. LiveReact 2.0 sends only what changed.

## How it works

The wrapper element carries three data attributes:

| Attribute           | Contents                                                        |
| ------------------- | --------------------------------------------------------------- |
| `data-props`        | Full snapshot of the props.                                     |
| `data-props-diff`   | Patch operations describing what changed since the last render. |
| `data-streams-diff` | Patch operations for stream assigns.                            |

The full snapshot in `data-props` is written on the initial render, and stays
current so a client that reconnects can resynchronize from it directly. Updates
travel through `data-props-diff`. A fourth attribute, `data-use-diff`, tells the
client hook which of the two to read.

Diffs are computed from LiveView's own change tracking, so a prop that did not
change produces no operations at all. When LiveView knows the previous value,
LiveReact diffs old against new and emits only the differing paths; lists of
maps are matched on their `id` field, so inserting into or reordering a list
does not resend the untouched entries.

The operations themselves are serialized in a compact format rather than JSON —
`LiveReact.Patch` documents the wire format.

## Configuration

Diffing is on by default. To turn it off everywhere:

```elixir
# config/config.exs
config :live_react, enable_props_diff: false
```

This is read with `Application.compile_env/3`, so changing it requires
recompiling `live_react` (`mix deps.compile live_react --force`).

To turn it off for a single component, which is useful when isolating a
suspected diffing problem:

```heex
<.react name="Chart" data={@points} diff={false} />
```

With diffing off, the component falls back to the 1.x behavior: the full props
payload is re-sent on every update.

## Encoding

Props are encoded through the `LiveReact.Encoder` protocol before being diffed.
Maps, lists, and primitives need nothing. Structs must derive the protocol,
which also decides which fields are exposed to the client:

```elixir
defmodule User do
  @derive {LiveReact.Encoder, except: [:password_hash]}
  defstruct [:id, :name, :email, :password_hash]
end
```

Requiring this explicitly is what keeps a struct from leaking fields nobody
meant to send to the browser. It is the one breaking change in 2.0 — see
[Upgrading to 2.0](upgrading-to-2.0.md).

### Built-in implementations

Some structs you are likely to pass to a component are already handled, and
arrive on the client in a shape that is convenient for React:

| Struct                                      | Encoded as                                                                          |
| ------------------------------------------- | ----------------------------------------------------------------------------------- |
| `Date`, `Time`, `NaiveDateTime`, `DateTime` | ISO 8601 string                                                                     |
| `Phoenix.HTML.Form`                         | `%{name, values, errors, valid}`                                                    |
| `Phoenix.LiveView.AsyncResult`              | `%{ok, loading, failed, result}`                                                    |
| `Phoenix.LiveView.UploadConfig`             | `%{ref, name, accept, max_entries, auto_upload, entries, errors}`                   |
| `Phoenix.LiveView.UploadEntry`              | `%{ref, client_name, client_size, client_type, progress, done, valid, preflighted}` |

Forms are the most useful of these. Passing a form built from an Ecto changeset
gives the React component the current field values, the validation errors keyed
by field, and whether the changeset is valid — so server-side validation can
drive client-side rendering without hand-rolling the serialization:

```heex
<.react name="SignupForm" form={@form} />
```

```jsx
export default function SignupForm({ form, pushEvent }) {
  return (
    <input
      value={form.values.email ?? ""}
      onChange={(e) => pushEvent("validate", { email: e.target.value })}
      aria-invalid={Boolean(form.errors.email)}
    />
  );
}
```

Uploads pair with the `upload` and `uploadTo` functions LiveReact passes to
every component, and `AsyncResult` lets a component render loading and failure
states from `assign_async/3` directly.

## Streams

`Phoenix.LiveView.stream/3,4` assigns can be passed straight to a component:

```elixir
def mount(_params, _session, socket) do
  {:ok, stream(socket, :messages, load_messages())}
end

def render(assigns) do
  ~H"""
  <.react name="Messages" messages={@streams.messages} />
  """
end
```

LiveReact detects the stream value and delivers it over `data-streams-diff`
instead of treating it as an ordinary prop. On the React side it arrives as an
array under the same name:

```jsx
export default function Messages({ messages }) {
  return (
    <ul>
      {messages.map((message) => (
        <li key={message.__dom_id}>{message.text}</li>
      ))}
    </ul>
  );
}
```

Each item carries the `__dom_id` LiveView assigned to it, which is a stable key
for React.

The stream operations map onto their LiveView counterparts:

| LiveView                                   | Effect on the client array                |
| ------------------------------------------ | ----------------------------------------- |
| `stream_insert/4`                          | Inserts at `:at`, or appends by default   |
| `stream_insert/4` with `update_only: true` | Replaces a matching item, inserts nothing |
| `stream_delete/3`                          | Removes the item with that dom id         |
| `stream/4` with `reset: true`              | Empties the array before applying inserts |
| `:limit`                                   | Truncates the array to the limit          |

Because the client holds the stream contents in memory, items stay available to
React — unlike LiveView streams in HEEx, where the server does not retain them.

## Troubleshooting

If a component stops updating, check whether its props are actually changing as
far as LiveView is concerned — diffs are derived from `__changed__`, so a prop
mutated in place without being reassigned produces no operations. Setting
`diff={false}` on the component is the quickest way to confirm whether diffing
is involved.
