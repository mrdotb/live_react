# Props Diffing & LiveView Streams for live_react

Date: 2026-07-13
Status: Approved, ready for implementation planning

## 1. Overview & Goals

Port two related features from `live_vue` to `live_react`:

1. **Props diffing** — instead of re-sending the full `data-props` JSON on every
   LiveView update, send only a JSON-Patch-style diff (`data-props-diff`),
   computed server-side via the `Jsonpatch` library.
2. **Stream support** — automatically detect `%Phoenix.LiveView.LiveStream{}`
   assigns (from `Phoenix.LiveView.stream/3,4`) and serialize their
   inserts/deletes/resets as patch operations over a separate
   `data-streams-diff` channel. This is the *only* way to expose streams at
   all, since a `LiveStream` never holds a full snapshot server-side by
   design — there is no "full props" fallback for stream data.

Both diffs share one wire format (a compact custom binary encoding, cheaper
than raw JSON) and one JSON-Patch-like operation vocabulary (`add` / `remove`
/ `replace` / `upsert` / `limit`).

The central design fork from `live_vue`: Vue applies patches by mutating a
`reactive()` proxy in place, and Vue's reactivity system auto-detects the
mutation. React has no equivalent — components (especially `React.memo`'d
ones) key off object/array *identity* to decide whether to re-render. The
client therefore applies patches **copy-on-write**: the same patch-walking
logic as `live_vue`, but the top-level structure being patched is cloned
before mutation on every update, so:

- Unaffected items keep their old reference (memoized rows skip re-render).
- Anything actually touched (replaced/inserted/removed) gets a fresh
  reference, so React always sees the right thing changed.

## 2. Elixir-side architecture

### New modules (`lib/live_react/`)

- **`LiveReact.Encoder`** — protocol ported from `LiveVue.Encoder`. Converts
  structs into plain maps before diffing (`Jsonpatch.diff/3` needs real maps,
  not opaque struct terms). Includes:
  - Primitive impls: `Integer`, `Float`, `BitString`, `Atom`, `List`, `Map`,
    the `Date`/`Time`/`NaiveDateTime`/`DateTime` family (encoded via
    `to_iso8601/1` so diffing compares strings, not tuples).
  - LiveView-specific impls: `Phoenix.HTML.Form`, `Phoenix.LiveView.AsyncResult`,
    `Phoenix.LiveView.UploadConfig`, `Phoenix.LiveView.UploadEntry`. The
    Ecto-changeset-aware parts of the `Form` impl stay conditional on
    `Code.ensure_loaded?(Ecto)`, matching `live_vue`'s existing optional-dep
    pattern (`{:ecto, optional: true}`, `{:phoenix_ecto, optional: true}`).
  - `Any` fallback raises `Protocol.UndefinedError` with a message pointing
    users at `@derive {LiveReact.Encoder, only: [...]}` /
    `Protocol.derive/3`, same as `live_vue`.

- **`LiveReact.Patch`** — ported near-verbatim from `LiveVue.Patch`; it's pure
  Elixir with nothing Vue-specific. Serializes/deserializes the compact patch
  wire format (`<op><path_len>:<path><value>` with tagged values: `z`/`b0`/
  `b1`/`n<len>:`/`s<len>:`/`J<len>:`), plus `encode_object/1` /
  `decode_object/1` for the caret-escaped JSON attribute encoding used for
  `data-props`/`data-slots`-style full-value attributes.

### Changes to `lib/live_react.ex` (`react/1`)

- Auto-detect `%Phoenix.LiveView.LiveStream{}` values in assigns (any key
  name, matching `live_vue`'s approach) and route them into a `streams` map
  instead of `props`.
- Add `@diff_default = Application.compile_env(:live_react, :enable_props_diff, true)`.
  Overridable per-instance with a `diff={false}` attribute, mirroring the
  existing `ssr={false}` convention.
- Compute `props_diff` via `Jsonpatch.diff/3`, using `LiveReact.Encoder.encode/1`
  as the `prepare_map` callback and an `:id`-field-based `object_hash`
  (`object_hash(%{id: id}), do: id`).
- Compute `streams_diff` by porting `calculate_streams_diff/2` and
  `generate_stream_patches/2` from `live_vue` verbatim: handles `reset?`,
  `deletes`, and `inserts` (respecting `at`/`limit`/`update_only`), no
  `Jsonpatch.diff` needed here since `Phoenix.LiveView.LiveStream` already
  hands us pre-computed inserts/deletes.
- Both diffs are serialized through `LiveReact.Patch.serialize/1` into
  `data-props-diff` / `data-streams-diff` attributes.
- Switch `data-props` encoding from raw `Jason.encode!/1` to
  `Encoder.encode(@props) |> Patch.encode_object()`, so the full snapshot and
  the incremental diffs stay structurally consistent. **This is a breaking
  change** for existing struct props — see §5.
- Rework `__changed__` bookkeeping so `data-props` is only marked changed on
  init / dead-render / diff-disabled; otherwise only `data-props-diff`
  carries updates. Add a `data-use-diff` attribute so the client knows
  whether to expect diffs or full replacement.
- `mix.exs`: add `{:jsonpatch, "~> 2.3"}`.

### Explicitly unchanged

- Slot handling (`LiveReact.Slots`) is untouched.
- SSR path (`SSR.render/3`) keeps receiving only `assigns.props` — streams are
  excluded from SSR, matching `live_vue`'s existing limitation. SSR'd HTML
  will not include stream items until the client hydrates and applies the
  initial `data-streams-diff`.

## 3. JS/client architecture

### New files (`assets/js/live_react/`)

live_react's client library is plain JS/JSX (no TypeScript build step for the
library itself, unlike `live_vue`'s `.ts` sources), so ports are written as
plain JS:

- **`compactPatch.js`** — port of `decodeCompactPatch`/`decodeCompactJson`
  verbatim. Pure decode logic, framework-agnostic, no changes needed.
- **`jsonPatch.js`** — port of `applyPatchOperation` / `applyPatch` /
  `getValueByPointer`, with one behavioral change: instead of mutating
  `document` in place, callers clone the top-level value being patched
  (shallow `{...obj}` / `[...arr]`, or `structuredClone` if a deep clone is
  ever warranted) before running the same op-application logic against the
  clone. Nested `replace`/`upsert` ops already swap in fresh objects at the
  point of change, so only the *outermost* container's reference needs
  refreshing for React to detect the update — unaffected leaf items keep
  their prior reference.

### `hooks.js` changes

The hook keeps two persistent pieces of state per instance:

- `this._props` — base props. Replaced wholesale on init / dead-render /
  diff-disabled; patched via `data-props-diff` otherwise.
- `this._streams` — never sent as a full snapshot. Built purely by applying
  `data-streams-diff` patches starting from `{}`, since that's the only
  channel stream data travels over.

Lifecycle:

- `mounted()`: parse `data-props` as today, then apply the initial
  `data-streams-diff` (server sends this as reset-then-insert-all on first
  render, same as `live_vue`) to seed `this._streams`. Merge both into props
  for the first render.
- `updated()`: if `data-use-diff === "true"`, apply `data-props-diff`
  (copy-on-write) to `this._props`; otherwise replace it wholesale from
  `data-props` (today's behavior, preserved as the diff-disabled path).
  Always apply `data-streams-diff` (copy-on-write) to `this._streams`.
  Re-render with `{...this._props, ...this._streams, pushEvent, pushEventTo,
  handleEvent, removeHandleEvent, upload, uploadTo}`.
- **New `reconnected()` handler** (live_react's hook does not define one
  today) — same handling as `updated()`. Necessary addition: without it, a
  server-process restart mid-session would not refresh diff/stream state on
  the client.
- `destroyed()`: unchanged.

## 4. Testing impact

`LiveReact.Test.get_react/2` currently always decodes `data-props` as the
full current state. Under diff mode that attribute stops being resent after
the initial render, so the helper needs updating — following `live_vue`'s
precedent directly rather than inventing something new:

- Expose new fields on the returned map: `props_diff`, `streams_diff` (raw
  deserialized patch ops via `LiveReact.Patch.deserialize/1`), `use_diff`.
- Document the escape hatch in moduledoc: setting
  `config :live_react, enable_props_diff: false` (e.g. in `config/test.exs`)
  makes `data-props` always carry the full snapshot, for tests that want to
  assert complete state rather than incremental diffs.
- Keep `Floki`-based parsing (`live_vue` switched to `LazyHTML`, but that's an
  unrelated, orthogonal change with no bearing on this feature).

Out of scope for this change: `LiveReact.Test`'s moduledoc currently
mentions a `:handlers` / `v-on:*` / `JS.push` concept copy-pasted from
`live_vue`'s docs that doesn't match live_react's actual implementation
(live_react has no handlers concept — it uses `pushEvent` functions
instead). Not being touched here; flagged as a pre-existing doc inconsistency
for a separate cleanup.

## 5. Breaking changes / migration

- **Struct props now require `LiveReact.Encoder`** instead of just
  `Jason.Encoder`, since `data-props` switches to
  `Encoder.encode/1 |> Patch.encode_object/1`. Any existing app passing a
  struct prop that only implements `Jason.Encoder` (or derives it) will start
  raising `Protocol.UndefinedError` until it `@derive`s `LiveReact.Encoder`
  (plain maps need no changes). This is the headline upgrade action and
  should be called out prominently in the CHANGELOG.
- `enable_props_diff` defaults to `true` (matching `live_vue`) — diffing
  turns on for everyone upgrading, not opt-in. This is a behavior change on
  upgrade (smaller wire payloads, but relies on the new `LiveReact.Encoder`
  protocol for any struct props), not purely additive.

## 6. Out of scope

Not porting, since they're Vue-template-specific conveniences with no React
equivalent need:

- `live_vue`'s `handlers` / `v-on:*` JS-command props — React uses
  `pushEvent` functions instead, already an existing live_react concept,
  unrelated to streams/diff.
- `v-inject` (slot-injection-into-another-component) feature.
- `LiveVue.SharedPropsView`.
