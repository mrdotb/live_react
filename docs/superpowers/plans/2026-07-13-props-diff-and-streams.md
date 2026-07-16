# Props Diffing & LiveView Streams Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port live_vue's props-diffing and LiveView-stream support to live_react, so both `data-props` diffs and `Phoenix.LiveView.stream/3,4` data travel to the client as compact JSON-Patch-style operations instead of full JSON payloads.

**Architecture:** Server-side, `LiveReact.Encoder` normalizes structs into diffable maps, `Jsonpatch.diff/3` computes prop diffs, and hand-rolled patch generation reads `%Phoenix.LiveView.LiveStream{}` inserts/deletes directly (no diffing library needed there). Both diff kinds are serialized through `LiveReact.Patch`'s compact wire format into `data-props-diff` / `data-streams-diff` attributes. Client-side, the React hook keeps persistent `_props` / `_streams` state per component instance and applies patches **copy-on-write**: only the top-level value at each patch's first path segment gets a fresh reference, so `React.memo`'d children correctly skip re-rendering for untouched items and re-render for changed ones.

**Tech Stack:** Elixir/Phoenix LiveView, `Jsonpatch` (new dep), Jason; plain JS/JSX client (no TypeScript in the library itself), Vitest + jsdom (new dev tooling) for client unit tests.

## Global Constraints

- Module names: `LiveReact.Encoder`, `LiveReact.Patch` (mirrors `LiveVue.Encoder`/`LiveVue.Patch` naming, adapted to this project).
- New Elixir dependency: `{:jsonpatch, "~> 2.3"}` in `mix.exs`.
- New per-instance attribute: `diff={false}` (mirrors the existing `ssr={false}` convention) to opt out of prop diffing; global default via `config :live_react, enable_props_diff: true` (default `true`).
- Wire attribute names match live_vue exactly: `data-props-diff`, `data-streams-diff`, `data-use-diff` (no reason to diverge — internal wire details, not public API).
- `data-props` switches from raw `Jason.encode!/1` to `LiveReact.Encoder.encode/1 |> LiveReact.Patch.encode_object/1`. This is a **breaking change**: struct props now require `LiveReact.Encoder` (via `@derive` or explicit `defimpl`) instead of just `Jason.Encoder`. Plain maps are unaffected.
- Client library files stay plain JS/JSX (`.js`/`.jsx`/`.mjs`), consistent with the existing `assets/js/live_react/` sources — no TypeScript is introduced.
- `object_hash` for diffing lists of maps/structs is hardcoded to the `:id` field, matching live_vue: `object_hash(%{id: id}), do: id`.
- Stream items get a `__dom_id` field merged in before encoding (e.g. `"users-1"`), used by the client for `$$dom_id`-based array lookups. This field name is unchanged from live_vue.

---

## File Structure

**New Elixir files:**
- `lib/live_react/patch.ex` — compact patch wire format (serialize/deserialize).
- `lib/live_react/encoder.ex` — `LiveReact.Encoder` protocol + built-in implementations.

**Modified Elixir files:**
- `lib/live_react.ex` — stream/prop classification, props_diff + streams_diff computation, template attributes.
- `lib/live_react/test.ex` — expose `props_diff` / `streams_diff` / `use_diff`, switch `props` decoding.
- `mix.exs` — add `jsonpatch` dependency.
- `CHANGELOG.md` — document the breaking change.

**New JS files:**
- `assets/js/live_react/compactPatch.js` — decode the compact wire format.
- `assets/js/live_react/jsonPatch.js` — apply patch operations, copy-on-write.
- `assets/js/live_react/tests/helpers.js` — mock LiveView hook context for hook tests.
- `vitest.config.js` (repo root) — test runner config.

**Modified JS files:**
- `assets/js/live_react/hooks.js` — persistent `_props`/`_streams` state, `reconnected()` lifecycle.
- `package.json` (repo root) — add `vitest`/`jsdom` dev deps and `test` scripts.

**New example files (manual verification):**
- `live_react_examples/lib/live_react_examples_web/live/stream_demo_live.ex`
- `live_react_examples/assets/react-components/stream-demo.jsx`

---

### Task 1: `LiveReact.Patch` wire format

**Files:**
- Create: `lib/live_react/patch.ex`
- Test: `test/live_react_patch_test.exs`

**Interfaces:**
- Produces: `LiveReact.Patch.serialize(patches :: [map()]) :: binary()`, `LiveReact.Patch.deserialize(payload :: binary()) :: [list()]`, `LiveReact.Patch.encode_object(value :: term()) :: binary()`, `LiveReact.Patch.decode_object(value :: binary()) :: term()`. All later tasks depend on these four functions.

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule LiveReactPatchTest do
  use ExUnit.Case

  alias LiveReact.Patch

  describe "values" do
    test "round-trips nil" do
      patches = [%{op: "replace", path: "/value", value: nil}]
      assert serialize_deserialize(patches) == patches
    end

    test "round-trips booleans" do
      patches = [
        %{op: "replace", path: "/enabled", value: true},
        %{op: "replace", path: "/disabled", value: false}
      ]

      assert serialize_deserialize(patches) == patches
    end

    test "round-trips integers" do
      patches = [%{op: "replace", path: "/count", value: 6}]
      assert serialize_deserialize(patches) == patches
    end

    test "round-trips floats" do
      patches = [%{op: "replace", path: "/price", value: 12.5}]
      assert serialize_deserialize(patches) == patches
    end

    test "round-trips strings" do
      patches = [%{op: "replace", path: "/title", value: "Published"}]
      assert serialize_deserialize(patches) == patches
    end

    test "round-trips lists" do
      patches = [%{op: "replace", path: "/tags", value: ["bug", "urgent"]}]
      assert serialize_deserialize(patches) == patches
    end

    test "round-trips maps" do
      patches = [%{op: "replace", path: "/user", value: %{"id" => 3, "name" => "Charlie"}}]
      assert serialize_deserialize(patches) == patches
    end

    test "round-trips caret-encoded JSON edge cases" do
      patches = [
        %{
          op: "replace",
          path: "/meta",
          value: %{"empty" => "", "caret" => "^", "tilde" => "~", "both" => "~^"}
        }
      ]

      assert serialize_deserialize(patches) == patches
    end
  end

  describe "paths" do
    test "round-trips the document root path" do
      patches = [%{op: "replace", path: "", value: %{"status" => "ready"}}]
      assert serialize_deserialize(patches) == patches
    end

    test "round-trips nested paths" do
      patches = [%{op: "replace", path: "/profile/name", value: "Ada"}]
      assert serialize_deserialize(patches) == patches
    end

    test "round-trips array index paths" do
      patches = [%{op: "replace", path: "/items/0/name", value: "Keyboard"}]
      assert serialize_deserialize(patches) == patches
    end

    test "round-trips append marker paths" do
      patches = [%{op: "add", path: "/items/-", value: "new"}]
      assert serialize_deserialize(patches) == patches
    end

    test "round-trips JSON pointer escapes in path segments" do
      patches = [%{op: "replace", path: "/settings/a~1b~0c", value: "value"}]
      assert serialize_deserialize(patches) == patches
    end

    test "round-trips UTF-8 paths and values using JavaScript string lengths" do
      patches = [
        %{op: "replace", path: "/profile/na.me", value: "zażółć"},
        %{op: "replace", path: "/emoji", value: "🚀"}
      ]

      assert Patch.serialize(patches) == "r14:/profile/na.mes6:zażółćr6:/emojis2:🚀"
      assert serialize_deserialize(patches) == patches
    end
  end

  describe "operations" do
    test "round-trips an empty patch list" do
      assert serialize_deserialize([]) == []
    end

    test "round-trips remove operations without a value" do
      patches = [%{op: "remove", path: "/items/0"}]
      assert serialize_deserialize(patches) == patches
    end

    test "omits nonce test operations when deserializing" do
      patches = [
        %{op: "test", path: "", value: 123},
        %{op: "replace", path: "/count", value: 6}
      ]

      assert serialize_deserialize(patches) == [%{op: "replace", path: "/count", value: 6}]
    end

    test "round-trips stream upsert and limit operations" do
      patches = [
        %{op: "upsert", path: "/users/-", value: %{"id" => 4, "name" => "Margaret Hamilton"}},
        %{op: "limit", path: "/users", value: 10}
      ]

      assert serialize_deserialize(patches) == patches
    end
  end

  describe "encode_object/decode_object" do
    test "round-trips a plain map" do
      value = %{"name" => "Ada", "count" => 3}
      assert value |> Patch.encode_object() |> Patch.decode_object() == value
    end

    test "escapes carets and tildes reversibly" do
      value = %{"weird" => "~^both^~"}
      assert value |> Patch.encode_object() |> Patch.decode_object() == value
    end
  end

  defp serialize_deserialize(patches) do
    patches
    |> Patch.serialize()
    |> Patch.deserialize()
    |> Enum.map(&patch_from_wire/1)
  end

  defp patch_from_wire([op, path]), do: %{op: op, path: path}
  defp patch_from_wire([op, path, value]), do: %{op: op, path: path, value: value}
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/live_react_patch_test.exs`
Expected: FAIL — `LiveReact.Patch` module not defined.

- [ ] **Step 3: Implement `LiveReact.Patch`**

```elixir
defmodule LiveReact.Patch do
  @moduledoc """
  Encodes LiveReact patch operations into the compact wire format used by
  `data-props-diff` and `data-streams-diff`.

  The payload is a concatenated sequence of operations. Dynamic text fields are
  JavaScript-string-length-prefixed, so paths and values can contain delimiters
  without extra escaping.

  Operation codes:

  | Code | Operation |
  | --- | --- |
  | `a` | `add` |
  | `d` | `remove` |
  | `r` | `replace` |
  | `u` | `upsert` |
  | `l` | `limit` |
  | `n` | nonce marker, ignored while decoding |

  Normal operations use:

  ```text
  <op><path_len>:<path><value>
  ```

  `remove` omits `<value>`. The nonce marker uses `n<digits>` and exists only
  to force LiveView to send a changed attribute.

  Value tags:

  | Tag | Value |
  | --- | --- |
  | `z` | `nil` |
  | `b0`, `b1` | booleans |
  | `n<len>:<number>` | number |
  | `s<len>:<string>` | string |
  | `J<len>:<caret-encoded JSON>` | maps, lists, and complex values |

  Paths are transported as JSON Pointer strings unchanged.
  """

  @doc """
  Serializes patch maps into a compact binary payload.

  Expected patch shapes are `%{op: op, path: path, value: value}`,
  `%{op: "remove", path: path}`, and `%{op: "test", path: "", value: nonce}`.
  The nonce test operation is encoded as a marker and is not returned by
  `deserialize/1`.
  """
  def serialize(patches) do
    :erlang.iolist_to_binary(for patch <- patches, do: serialize_op(patch))
  end

  @doc """
  Encodes a JSON value for safe, compact HTML attribute transport.

  The value is encoded with Jason's default JSON escaping, then JSON quote
  characters are replaced with `^`. Literal `~` and `^` characters are escaped
  as `~~` and `~^`, so the transform is reversible by `decode_object/1`.
  """
  def encode_object(value) do
    value
    |> Jason.encode!()
    |> String.replace("~", "~~")
    |> String.replace("^", "~^")
    |> String.replace("\"", "^")
  end

  @doc false
  def decode_object(value) when is_binary(value) do
    value
    |> String.replace(~r/~~|~\^|\^/, fn
      "~~" -> "~"
      "~^" -> "^"
      "^" -> "\""
    end)
    |> Jason.decode!()
  end

  @doc """
  Deserializes a compact patch payload into list-shaped operations.

  Returns `[]` for an empty payload. Decoded operations are shaped as
  `[op, path]` for `remove` and `[op, path, value]` for all value-bearing
  operations. Nonce markers are skipped.
  """
  def deserialize(""), do: []

  def deserialize(payload) when is_binary(payload) do
    payload
    |> parse_ops([])
    |> Enum.reverse()
  end

  defp serialize_op(%{op: "test", path: "", value: nonce}), do: ["n", to_string(nonce)]

  defp serialize_op(%{op: op, path: path, value: value}) do
    path = encode_path(path)
    [op_code(op), Integer.to_string(js_string_length(path)), ?:, path, encode_value(value)]
  end

  defp serialize_op(%{op: op, path: path}) do
    path = encode_path(path)
    [op_code(op), Integer.to_string(js_string_length(path)), ?:, path]
  end

  defp encode_path(path), do: path

  defp encode_value(nil), do: "z"
  defp encode_value(true), do: "b1"
  defp encode_value(false), do: "b0"

  defp encode_value(value) when is_number(value) do
    encoded = to_string(value)
    ["n", Integer.to_string(js_string_length(encoded)), ?:, encoded]
  end

  defp encode_value(value) when is_binary(value), do: ["s", Integer.to_string(js_string_length(value)), ?:, value]

  defp encode_value(value) do
    encoded = encode_object(value)
    ["J", Integer.to_string(js_string_length(encoded)), ?:, encoded]
  end

  defp parse_ops("", acc), do: acc

  defp parse_ops("n" <> rest, acc) do
    {_nonce, rest} = take_digits(rest)
    parse_ops(rest, acc)
  end

  defp parse_ops(<<code::binary-size(1), rest::binary>>, acc) do
    {path_length, rest} = take_length(rest)
    {path, rest} = take_js_string(rest, path_length)
    op = op_from_code(code)
    parse_op(op, path, rest, acc)
  end

  defp parse_op("remove", path, rest, acc), do: parse_ops(rest, [["remove", path] | acc])

  defp parse_op(op, path, rest, acc) do
    {value, rest} = parse_value(rest)
    parse_ops(rest, [[op, path, value] | acc])
  end

  defp parse_value("z" <> rest), do: {nil, rest}
  defp parse_value("b1" <> rest), do: {true, rest}
  defp parse_value("b0" <> rest), do: {false, rest}

  defp parse_value(<<tag::binary-size(1), rest::binary>>) when tag in ["n", "s", "J"] do
    {length, rest} = take_length(rest)
    {encoded, rest} = take_js_string(rest, length)

    value =
      case tag do
        "n" -> parse_number(encoded)
        "s" -> encoded
        "J" -> decode_object(encoded)
      end

    {value, rest}
  end

  defp parse_number(value) do
    case Integer.parse(value) do
      {integer, ""} ->
        integer

      _ ->
        {float, ""} = Float.parse(value)
        float
    end
  end

  defp take_length(payload) do
    {digits, ":" <> rest} = take_digits(payload)
    {String.to_integer(digits), rest}
  end

  defp take_digits(payload), do: take_digits(payload, "")

  defp take_digits(<<char, rest::binary>>, acc) when char in ?0..?9 do
    take_digits(rest, <<acc::binary, char>>)
  end

  defp take_digits(rest, acc), do: {acc, rest}

  defp take_js_string(payload, length), do: take_js_string(payload, payload, length, 0)

  defp take_js_string(original, _rest, 0, bytes) do
    <<value::binary-size(bytes), rest::binary>> = original
    {value, rest}
  end

  defp take_js_string(original, <<codepoint::utf8, rest::binary>>, remaining, bytes) do
    units = js_code_units(codepoint)
    if units > remaining, do: raise(ArgumentError, "Invalid LiveReact patch length prefix")
    take_js_string(original, rest, remaining - units, bytes + utf8_byte_size(codepoint))
  end

  defp js_string_length(value), do: js_string_length(value, 0)
  defp js_string_length(<<>>, acc), do: acc

  defp js_string_length(<<codepoint::utf8, rest::binary>>, acc),
    do: js_string_length(rest, acc + js_code_units(codepoint))

  defp js_code_units(codepoint) when codepoint > 0xFFFF, do: 2
  defp js_code_units(_codepoint), do: 1

  defp utf8_byte_size(codepoint) when codepoint <= 0x7F, do: 1
  defp utf8_byte_size(codepoint) when codepoint <= 0x7FF, do: 2
  defp utf8_byte_size(codepoint) when codepoint <= 0xFFFF, do: 3
  defp utf8_byte_size(_codepoint), do: 4

  defp op_code("add"), do: "a"
  defp op_code("remove"), do: "d"
  defp op_code("replace"), do: "r"
  defp op_code("upsert"), do: "u"
  defp op_code("limit"), do: "l"

  defp op_from_code("a"), do: "add"
  defp op_from_code("d"), do: "remove"
  defp op_from_code("r"), do: "replace"
  defp op_from_code("u"), do: "upsert"
  defp op_from_code("l"), do: "limit"
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/live_react_patch_test.exs`
Expected: PASS (all tests green).

- [ ] **Step 5: Commit**

```bash
git add lib/live_react/patch.ex test/live_react_patch_test.exs
git commit -m "feat: add LiveReact.Patch compact wire format"
```

---

### Task 2: `LiveReact.Encoder` protocol core

**Files:**
- Create: `lib/live_react/encoder.ex`
- Test: `test/live_react_encoder_test.exs`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `LiveReact.Encoder.encode(value :: term(), opts :: keyword()) :: term()`. Tasks 3, 5, and 6 call this.

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule LiveReact.EncoderTest do
  use ExUnit.Case

  alias LiveReact.Encoder

  describe "primitive types" do
    test "encodes integers, floats, strings, booleans, nil, atoms" do
      assert Encoder.encode(42) == 42
      assert Encoder.encode(3.14) == 3.14
      assert Encoder.encode("hello") == "hello"
      assert Encoder.encode(true) == true
      assert Encoder.encode(false) == false
      assert Encoder.encode(nil) == nil
      assert Encoder.encode(:hello) == :hello
    end
  end

  describe "complex types" do
    test "encodes lists recursively" do
      assert Encoder.encode([1, [2, 3], 4]) == [1, [2, 3], 4]
      assert Encoder.encode([]) == []
    end

    test "encodes maps recursively" do
      nested = %{user: %{name: "John", age: 30}, items: [1, 2, 3]}
      assert Encoder.encode(nested) == nested
    end
  end

  defmodule TestUser do
    @moduledoc false
    @derive Encoder
    defstruct [:name, :age, :email]
  end

  defmodule TestAccount do
    @moduledoc false
    @derive Encoder
    defstruct [:user, :balance]
  end

  defmodule DerivedUserOnly do
    @moduledoc false
    @derive {Encoder, only: [:name, :age]}
    defstruct [:name, :age, :email, :password]
  end

  defmodule DerivedUserExcept do
    @moduledoc false
    @derive {Encoder, except: [:password]}
    defstruct [:name, :age, :email, :password]
  end

  defmodule NotDerivedUser do
    @moduledoc false
    defstruct [:name, :age, :email]
  end

  describe "structs" do
    test "encodes structs to maps without __struct__" do
      user = %TestUser{name: "John", age: 30, email: "john@example.com"}
      encoded = Encoder.encode(user)

      assert encoded == %{name: "John", age: 30, email: "john@example.com"}
      refute Map.has_key?(encoded, :__struct__)
    end

    test "encodes nested structs" do
      account = %TestAccount{user: %TestUser{name: "John", age: 30, email: "j@x.com"}, balance: 1000}

      assert Encoder.encode(account) == %{
               user: %{name: "John", age: 30, email: "j@x.com"},
               balance: 1000
             }
    end

    test "encodes structs in lists and maps" do
      users = [%TestUser{name: "John", age: 30, email: "j@x.com"}]
      assert Encoder.encode(users) == [%{name: "John", age: 30, email: "j@x.com"}]

      assert Encoder.encode(%{admin: %TestUser{name: "Jane", age: 25, email: "ja@x.com"}}) ==
               %{admin: %{name: "Jane", age: 25, email: "ja@x.com"}}
    end
  end

  describe "deriving functionality" do
    test "derives encoder with only specified fields" do
      user = %DerivedUserOnly{name: "John", age: 30, email: "j@x.com", password: "secret"}
      assert Encoder.encode(user) == %{name: "John", age: 30}
    end

    test "derives encoder excluding specified fields" do
      user = %DerivedUserExcept{name: "John", age: 30, email: "j@x.com", password: "secret"}
      assert Encoder.encode(user) == %{name: "John", age: 30, email: "j@x.com"}
    end

    test "non-derived structs raise protocol error" do
      struct = %NotDerivedUser{name: "John", age: 30, email: "j@x.com"}

      assert_raise Protocol.UndefinedError, ~r/LiveReact.Encoder protocol must always be explicitly implemented/, fn ->
        Encoder.encode(struct)
      end
    end
  end

  describe "date and time types" do
    test "encodes date and time types as ISO8601 strings" do
      date = ~D[2023-01-01]
      naive_datetime = ~N[2023-01-01 12:00:00]
      datetime = DateTime.from_naive!(naive_datetime, "Etc/UTC")

      assert Encoder.encode(date) == Date.to_iso8601(date)
      assert Encoder.encode(naive_datetime) == NaiveDateTime.to_iso8601(naive_datetime)
      assert Encoder.encode(datetime) == DateTime.to_iso8601(datetime)
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/live_react_encoder_test.exs`
Expected: FAIL — `LiveReact.Encoder` module not defined.

- [ ] **Step 3: Implement the protocol core**

```elixir
defprotocol LiveReact.Encoder do
  @moduledoc """
  Protocol for encoding values to JSON for LiveReact.

  This protocol is used to safely transform structs into plain maps before
  calculating JSON patches. It ensures that struct fields are explicitly
  exposed and prevents accidental exposure of sensitive data.

  It's very similar to Jason.Encoder, but it's converting structs to maps instead of strings.

  ## Deriving

  The protocol allows leveraging Elixir's `@derive` feature to simplify protocol
  implementation in trivial cases. Accepted options are:

  * `:only` - encodes only values of specified keys.
  * `:except` - encodes all struct fields except specified keys.

  By default all keys except the `:__struct__` key are encoded.

  ## Example

      defmodule User do
        @derive LiveReact.Encoder
        defstruct [:name, :email, :password]
      end

  If we called `@derive {LiveReact.Encoder, only: [:name, :email]}`, only the
  specified fields would be encoded. If we called
  `@derive {LiveReact.Encoder, except: [:password]}`, all fields except the
  specified ones would be encoded.

  ## Deriving outside of the module

      Protocol.derive(LiveReact.Encoder, User, only: [...])

  ## Custom implementations

      defimpl LiveReact.Encoder, for: User do
        def encode(struct, opts) do
          struct
          |> Map.take([:first, :second])
          |> LiveReact.Encoder.encode(opts)
        end
      end
  """

  @type t :: term
  @type opts :: Keyword.t()
  @fallback_to_any true

  @doc """
  Encodes a value to one of the primitive types.
  """
  @spec encode(t, opts) :: any()
  def encode(value, opts \\ [])
end

defimpl LiveReact.Encoder, for: Integer do
  def encode(value, _opts), do: value
end

defimpl LiveReact.Encoder, for: Float do
  def encode(value, _opts), do: value
end

defimpl LiveReact.Encoder, for: BitString do
  def encode(value, _opts), do: value
end

defimpl LiveReact.Encoder, for: Atom do
  def encode(atom, _opts), do: atom
end

defimpl LiveReact.Encoder, for: List do
  def encode(list, opts) do
    Enum.map(list, &LiveReact.Encoder.encode(&1, opts))
  end
end

defimpl LiveReact.Encoder, for: Map do
  def encode(map, opts) do
    Map.new(map, fn {key, value} ->
      {key, LiveReact.Encoder.encode(value, opts)}
    end)
  end
end

defimpl LiveReact.Encoder, for: [Date, Time, NaiveDateTime, DateTime] do
  def encode(value, _opts) do
    @for.to_iso8601(value)
  end
end

defimpl LiveReact.Encoder, for: Any do
  defmacro __deriving__(module, struct, opts) do
    fields = fields_to_encode(struct, opts)

    quote do
      defimpl LiveReact.Encoder, for: unquote(module) do
        def encode(struct, opts) do
          struct
          |> Map.take(unquote(fields))
          |> LiveReact.Encoder.encode(opts)
        end
      end
    end
  end

  def encode(%{__struct__: module} = struct, _opts) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: """
      LiveReact.Encoder protocol must always be explicitly implemented.

      It's used to encode structs to JSON for LiveReact. It's very similar to Jason.Encoder,
      but it's converting structs to maps so LiveReact can diff them correctly.

      If you own the struct, you can derive the implementation specifying \
      which fields should be encoded:

          defmodule #{inspect(module)} do
            @derive {LiveReact.Encoder, only: [...]}
            defstruct ...
          end

      If you don't own the struct you want to encode, \
      you may use Protocol.derive/3 placed outside of any module:

          Protocol.derive(LiveReact.Encoder, #{inspect(module)}, only: [...])
          Protocol.derive(LiveReact.Encoder, #{inspect(module)})

      Nothing prevents you from defining your own implementation for the struct:

      defimpl LiveReact.Encoder, for: #{inspect(module)} do
        def encode(struct, opts) do
          struct
          |> Map.take([:first, :second])
          |> LiveReact.Encoder.encode(opts)
        end
      end
      """
  end

  def encode(value, _opts), do: value

  defp fields_to_encode(struct, opts) do
    fields = Map.keys(struct)

    cond do
      only = Keyword.get(opts, :only) ->
        case only -- fields do
          [] ->
            only

          error_keys ->
            raise ArgumentError,
                  ":only specified keys (#{inspect(error_keys)}) that are not defined in defstruct: " <>
                    "#{inspect(fields -- [:__struct__])}"
        end

      except = Keyword.get(opts, :except) ->
        case except -- fields do
          [] ->
            fields -- [:__struct__ | except]

          error_keys ->
            raise ArgumentError,
                  ":except specified keys (#{inspect(error_keys)}) that are not defined in defstruct: " <>
                    "#{inspect(fields -- [:__struct__])}"
        end

      true ->
        fields -- [:__struct__]
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/live_react_encoder_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/live_react/encoder.ex test/live_react_encoder_test.exs
git commit -m "feat: add LiveReact.Encoder protocol core"
```

---

### Task 3: `LiveReact.Encoder` LiveView struct implementations

**Files:**
- Modify: `lib/live_react/encoder.ex`
- Test: `test/live_react_encoder_liveview_test.exs`

**Interfaces:**
- Consumes: `LiveReact.Encoder.encode/2` (Task 2).
- Produces: `LiveReact.Encoder` implementations for `Phoenix.LiveView.AsyncResult`, `Phoenix.LiveView.UploadConfig`, `Phoenix.LiveView.UploadEntry`. No new public functions — later tasks rely on these structs being encodable when passed as props.

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule LiveReact.Encoder.LiveViewTest do
  use ExUnit.Case

  alias LiveReact.Encoder
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.UploadConfig
  alias Phoenix.LiveView.UploadEntry

  describe "AsyncResult" do
    test "encodes loading state" do
      result = AsyncResult.loading()
      encoded = Encoder.encode(result)

      assert encoded.ok == false
      assert encoded.loading == true
      assert encoded.result == nil
    end

    test "encodes successful state" do
      result = AsyncResult.loading() |> AsyncResult.ok("value")
      encoded = Encoder.encode(result)

      assert encoded.ok == true
      assert encoded.result == "value"
    end

    test "encodes failed state" do
      result = AsyncResult.loading() |> AsyncResult.failed({:error, "boom"})
      encoded = Encoder.encode(result)

      assert encoded.ok == false
      assert encoded.failed == "boom"
    end
  end

  describe "UploadEntry / UploadConfig" do
    test "encodes an empty UploadConfig" do
      config = UploadConfig.build_upload_config(%{accept: :any, max_entries: 1}, :avatar, [])
      encoded = Encoder.encode(config)

      assert encoded.ref
      assert encoded.name == :avatar
      assert encoded.entries == []
      assert encoded.errors == []
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/live_react_encoder_liveview_test.exs`
Expected: FAIL — `Protocol.UndefinedError` for `AsyncResult`/`UploadConfig`.

- [ ] **Step 3: Add the LiveView-specific implementations**

Append to `lib/live_react/encoder.ex` (after the `Any` impl block from Task 2):

```elixir
defimpl LiveReact.Encoder, for: Phoenix.LiveView.AsyncResult do
  def encode(%Phoenix.LiveView.AsyncResult{} = struct, opts) do
    LiveReact.Encoder.encode(
      %{
        ok: struct.ok?,
        loading: struct.loading,
        failed: encode_failed(struct.failed),
        result: struct.result
      },
      opts
    )
  end

  defp encode_failed({:error, reason}), do: reason
  defp encode_failed({:exit, reason}), do: reason
  defp encode_failed(other), do: other
end

defimpl LiveReact.Encoder, for: Phoenix.LiveView.UploadConfig do
  def encode(%Phoenix.LiveView.UploadConfig{} = struct, opts) do
    errors =
      Enum.map(struct.errors, fn {key, value} ->
        %{ref: key, error: LiveReact.Encoder.encode(value, opts)}
      end)

    entries =
      Enum.map(struct.entries, fn entry ->
        encoded = LiveReact.Encoder.encode(entry, opts)
        entry_errors = errors |> Enum.filter(&(&1.ref == entry.ref)) |> Enum.map(& &1.error)
        Map.put(encoded, :errors, entry_errors)
      end)

    LiveReact.Encoder.encode(
      %{
        ref: struct.ref,
        name: struct.name,
        accept: struct.accept,
        max_entries: struct.max_entries,
        auto_upload: struct.auto_upload?,
        entries: entries,
        errors: errors
      },
      opts
    )
  end
end

defimpl LiveReact.Encoder, for: Phoenix.LiveView.UploadEntry do
  def encode(%Phoenix.LiveView.UploadEntry{} = struct, opts) do
    LiveReact.Encoder.encode(
      %{
        ref: struct.ref,
        client_name: struct.client_name,
        client_size: struct.client_size,
        client_type: struct.client_type,
        progress: struct.progress,
        done: struct.done?,
        valid: struct.valid?,
        preflighted: struct.preflighted?
      },
      opts
    )
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/live_react_encoder_liveview_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/live_react/encoder.ex test/live_react_encoder_liveview_test.exs
git commit -m "feat: encode LiveView AsyncResult/Upload structs via LiveReact.Encoder"
```

---

### Task 4: `mix.exs` dependency + stream/prop classification in `react/1`

**Files:**
- Modify: `mix.exs`
- Modify: `lib/live_react.ex`
- Test: `test/live_react_classification_test.exs`

**Interfaces:**
- Consumes: nothing new.
- Produces: `normalize_key/2` now classifies `%Phoenix.LiveView.LiveStream{}` values as `:streams` (distinct from `:props`), and a `:diff` special key is recognized (so it isn't treated as a prop). Task 5/6 build on this classification to extract `streams` separately from `props`.

- [ ] **Step 1: Add the dependency**

In `mix.exs`, add to `defp deps do`:

```elixir
{:jsonpatch, "~> 2.3"},
```

Run: `mix deps.get`
Expected: `jsonpatch` fetched successfully.

- [ ] **Step 2: Write the failing test**

```elixir
defmodule LiveReactClassificationTest do
  use ExUnit.Case

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias LiveReact.Test
  alias Phoenix.LiveView.LiveStream

  def stream_component(assigns) do
    ~H"""
    <.react name="TestComponent" users={@users} title={@title} />
    """
  end

  test "LiveStream values are excluded from props" do
    stream = LiveStream.new(:users, make_ref(), [], [])

    html =
      render_component(&stream_component/1, users: stream, title: "My Page")

    react = Test.get_react(html)

    assert react.props == %{"title" => "My Page"}
  end
end
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `mix test test/live_react_classification_test.exs`
Expected: FAIL — `react.props` still includes a (non-JSON-encodable or malformed) `users` key, since `%LiveStream{}` isn't yet classified separately and `Jsonpatch`/`Encoder` aren't wired into `data-props` yet (this will actually raise, since `Jason.encode!` cannot encode a `%LiveStream{}` struct without a `Jason.Encoder` impl — confirming the gap).

- [ ] **Step 4: Classify `%LiveStream{}` in `lib/live_react.ex`**

In `lib/live_react.ex`, add the alias and extend `normalize_key/2`:

```elixir
alias Phoenix.LiveView.LiveStream
```

```elixir
defp normalize_key(key, _val) when key in ~w(id class ssr diff name socket __changed__ __given__)a,
  do: :special

defp normalize_key(_key, [%{__slot__: _}]), do: :slots
defp normalize_key(key, val) when is_atom(key), do: key |> to_string() |> normalize_key(val)
defp normalize_key(_key, %LiveStream{}), do: :streams
defp normalize_key(_key, _val), do: :props
```

(Note: `%LiveStream{}` clause must come after the `is_atom(key)` string-conversion clause and before the catch-all `:props` clause, matching the existing pattern-match order.)

No other code changes are needed for this task: `react/1`'s existing `extract(assigns, :props)` call already filters by `normalize_key/2`, so once `%LiveStream{}` values classify as `:streams` instead of `:props`, they're automatically excluded from `data-props`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `mix test test/live_react_classification_test.exs`
Expected: PASS.

- [ ] **Step 6: Run the full existing suite to check for regressions**

Run: `mix test`
Expected: PASS (existing `live_react_test.exs` still green — stream classification is additive).

- [ ] **Step 7: Commit**

```bash
git add mix.exs mix.lock lib/live_react.ex test/live_react_classification_test.exs
git commit -m "feat: classify LiveStream assigns separately from props, add jsonpatch dep"
```

---

### Task 5: Props diffing in `react/1`

**Files:**
- Modify: `lib/live_react.ex`
- Test: `test/live_react_props_diff_test.exs`

**Interfaces:**
- Consumes: `LiveReact.Encoder.encode/1` (Task 2/3), `LiveReact.Patch.serialize/1` + `encode_object/1` (Task 1), `Jsonpatch.diff/3` (Task 4 dependency).
- Produces: `data-props`, `data-props-diff`, `data-use-diff` attributes on the rendered `<div>`; a `diff={false}` per-instance opt-out; `@diff_default` config key `:enable_props_diff`. `LiveReact.Test` (Task 7) reads these attributes.

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule LiveReactPropsDiffTest do
  use ExUnit.Case

  import Phoenix.Component

  alias LiveReact.Test

  defp render_react_assigns(assigns) do
    rendered = LiveReact.react(assigns)
    html = rendered |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    Test.get_react(html)
  end

  defp assert_patches_equal(actual, expected) do
    actual_sorted = actual |> decode_patch() |> Enum.sort_by(& &1["path"])
    expected_sorted = Enum.sort_by(expected, & &1["path"])
    assert actual_sorted == expected_sorted
  end

  defp decode_patch(patch_list) do
    patch_list
    |> Enum.map(fn
      [op, path] -> %{"op" => op, "path" => path}
      [op, path, value] -> %{"op" => op, "path" => path, "value" => value}
    end)
    |> Enum.reject(&(&1["op"] == "test"))
  end

  describe "props_diff functionality" do
    test "initial render has empty props_diff and use_diff true" do
      assigns = %{name: "John", age: 30, "socket": nil, __changed__: nil}

      react = render_react_assigns(assigns)

      assert react.props == %{"name" => "John", "age" => 30}
      assert react.use_diff == true
      assert_patches_equal(react.props_diff, [])
    end

    test "single simple prop change creates replace operation" do
      assigns = %{name: "John", age: 30, __changed__: %{}}
      assigns = assign(assigns, :name, "Jane")

      react = render_react_assigns(assigns)

      assert_patches_equal(react.props_diff, [%{"op" => "replace", "path" => "/name", "value" => "Jane"}])
    end

    test "complex prop changes use Jsonpatch.diff for minimal operations" do
      assigns = %{user: %{name: "John", age: 30}, __changed__: %{}}
      assigns = assign(assigns, :user, %{name: "Alice", age: 25})

      react = render_react_assigns(assigns)

      assert_patches_equal(react.props_diff, [
        %{"op" => "replace", "path" => "/user/age", "value" => 25},
        %{"op" => "replace", "path" => "/user/name", "value" => "Alice"}
      ])
    end

    test "unchanged props do not appear in diff" do
      assigns = %{name: "John", age: 30, __changed__: %{}}
      assigns = assign(assigns, :name, "Bob")

      react = render_react_assigns(assigns)

      assert_patches_equal(react.props_diff, [%{"op" => "replace", "path" => "/name", "value" => "Bob"}])
    end

    test "lists are diffed based on id field" do
      assigns = %{
        items: [%{id: 1, name: "Alice"}, %{id: 2, name: "Bob"}],
        __changed__: %{}
      }

      assigns = assign(assigns, :items, [%{id: 1, name: "Alice"}, %{id: 2, name: "New Bob"}])

      react = render_react_assigns(assigns)

      assert_patches_equal(react.props_diff, [
        %{"op" => "replace", "path" => "/items/1/name", "value" => "New Bob"}
      ])
    end

    test "it's possible to disable diffs per-instance" do
      assigns = %{user: %{name: "John", age: 30}, diff: false, __changed__: %{}}
      assigns = assign(assigns, :user, %{name: "Jane", age: 25})

      react = render_react_assigns(assigns)

      assert react.use_diff == false
      assert react.props == %{"user" => %{"name" => "Jane", "age" => 25}}
      assert_patches_equal(react.props_diff, [])
    end

    defmodule User do
      @moduledoc false
      @derive LiveReact.Encoder
      defstruct [:name, :age]
    end

    test "for structs uses LiveReact.Encoder to convert to map" do
      assigns = %{user: %User{name: "John", age: 30}, __changed__: %{}}
      assigns = assign(assigns, :user, %User{name: "Alice", age: 25})

      react = render_react_assigns(assigns)

      assert_patches_equal(react.props_diff, [
        %{"op" => "replace", "path" => "/user/age", "value" => 25},
        %{"op" => "replace", "path" => "/user/name", "value" => "Alice"}
      ])
    end

    test "struct props without LiveReact.Encoder raise a helpful error" do
      defmodule Undecoded do
        @moduledoc false
        defstruct [:name]
      end

      assigns = %{user: %Undecoded{name: "John"}, __changed__: nil}

      assert_raise Protocol.UndefinedError, ~r/LiveReact.Encoder protocol must always be explicitly implemented/, fn ->
        render_react_assigns(assigns)
      end
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/live_react_props_diff_test.exs`
Expected: FAIL — `react.props_diff`/`react.use_diff` are `nil` (attributes don't exist yet), and `render_react_assigns/1` errors since `data-props` still uses raw `Jason.encode!`.

- [ ] **Step 3: Implement props diffing in `lib/live_react.ex`**

Replace the body of `lib/live_react.ex` with:

```elixir
defmodule LiveReact do
  @moduledoc """
  See READ.md for installation instructions and examples.
  """

  use Phoenix.Component
  import Phoenix.HTML

  alias LiveReact.Encoder
  alias LiveReact.Patch
  alias LiveReact.SSR
  alias LiveReact.Slots
  alias Phoenix.LiveView
  alias Phoenix.LiveView.LiveStream

  require Logger

  @ssr_default Application.compile_env(:live_react, :ssr, true)
  @diff_default Application.compile_env(:live_react, :enable_props_diff, true)

  @doc """
  Render a React component.
  """
  def react(assigns) do
    init = assigns.__changed__ == nil
    dead = assigns[:socket] == nil or not LiveView.connected?(assigns[:socket])
    use_diff = Map.get(assigns, :diff, @diff_default)
    use_streams_diff = Enum.any?(assigns, fn {_k, v} -> match?(%LiveStream{}, v) end)
    render_ssr? = init and dead and Map.get(assigns, :ssr, @ssr_default)

    base_assigns =
      if use_diff do
        Enum.filter(assigns, fn {k, _v} -> key_changed(assigns, k) end)
      else
        assigns
      end

    {props, _} = extract(base_assigns, :props)
    {streams, _} = extract(base_assigns, :streams)
    {slots, slots_changed?} = extract(assigns, :slots)
    component_name = Map.get(assigns, :name)

    props_diff = if use_diff, do: calculate_props_diff(props, assigns), else: []
    streams_diff = if use_streams_diff, do: calculate_streams_diff(streams, init or dead), else: []

    assigns =
      assigns
      |> Map.put_new(:class, nil)
      |> Map.put(:__component_name, component_name)
      |> Map.put(:props, props)
      |> Map.put(:props_diff, Patch.serialize(props_diff))
      |> Map.put(:streams_diff, Patch.serialize(streams_diff))
      |> Map.put(:use_diff, use_diff)
      |> Map.put(:slots, if(slots_changed?, do: Slots.rendered_slot_map(slots), else: %{}))

    assigns =
      Map.put(assigns, :ssr_render, if(render_ssr?, do: ssr_render(assigns), else: nil))

    computed_changed =
      %{
        props: init or dead or not use_diff,
        slots: slots_changed?,
        ssr_render: render_ssr?,
        props_diff: not init and not dead and use_diff,
        streams_diff: use_streams_diff
      }

    assigns =
      update_in(assigns.__changed__, fn
        nil -> nil
        changed -> for {k, true} <- computed_changed, into: changed, do: {k, true}
      end)

    # It's important to not add extra `\n` in the inner div or it will break hydration
    ~H"""
    <div
      id={assigns[:id] || id(@__component_name)}
      data-name={@__component_name}
      data-props={"#{Patch.encode_object(Encoder.encode(@props))}"}
      data-props-diff={"#{@props_diff}"}
      data-streams-diff={"#{@streams_diff}"}
      data-slots={"#{@slots |> Slots.base_encode_64 |> json}"}
      data-ssr={is_map(@ssr_render)}
      data-use-diff={@use_diff |> to_string()}
      phx-update="ignore"
      phx-hook="ReactHook"
      class={@class}
    ><%= raw(@ssr_render[:html]) %></div>
    """
  end

  # Calculates minimal JSON Patch operations for changed props only.
  # Uses Phoenix LiveView's __changed__ tracking to identify what props have changed.
  defp calculate_props_diff(props, %{__changed__: changed}) do
    props
    |> Enum.flat_map(fn {k, new_value} ->
      case changed[k] do
        nil ->
          []

        true ->
          [%{op: "replace", path: "/#{k}", value: Encoder.encode(new_value)}]

        old_value ->
          Jsonpatch.diff(old_value, new_value,
            ancestor_path: "/#{k}",
            prepare_map: fn
              struct when is_struct(struct) -> Encoder.encode(struct)
              rest -> rest
            end,
            object_hash: &object_hash/1
          )
      end
    end)
    |> then(fn diff -> [%{op: "test", path: "", value: :rand.uniform(10_000_000)} | diff] end)
  end

  defp object_hash(%{id: id}), do: id
  defp object_hash(_), do: nil

  # streams_diff implementation added in Task 6
  defp calculate_streams_diff(_streams, _initial), do: []

  defp extract(assigns, type) do
    Enum.reduce(assigns, {%{}, false}, fn {key, value}, {acc, changed} ->
      case normalize_key(key, value) do
        ^type -> {Map.put(acc, key, value), changed || key_changed(assigns, key)}
        _ -> {acc, changed}
      end
    end)
  end

  defp normalize_key(key, _val) when key in ~w(id class ssr diff name socket __changed__ __given__)a,
    do: :special

  defp normalize_key(_key, [%{__slot__: _}]), do: :slots
  defp normalize_key(key, val) when is_atom(key), do: key |> to_string() |> normalize_key(val)
  defp normalize_key(_key, %LiveStream{}), do: :streams
  defp normalize_key(_key, _val), do: :props

  defp key_changed(%{__changed__: nil}, _key), do: true
  defp key_changed(%{__changed__: changed}, key), do: changed[key] != nil

  defp ssr_render(assigns) do
    try do
      name = Map.get(assigns, :name)

      SSR.render(name, Encoder.encode(assigns.props), assigns.slots)
    rescue
      SSR.NotConfigured ->
        nil
    end
  end

  defp json(data), do: Jason.encode!(data, escape: :html_safe)

  defp id(name) do
    # a small trick to avoid collisions of IDs but keep them consistent across dead and live render
    # id(name) is called only once during the whole LiveView lifecycle because it's not using any assigns
    number = Process.get(:live_react_counter, 1)
    Process.put(:live_react_counter, number + 1)
    "#{name}-#{number}"
  end
end
```

(`calculate_streams_diff/2` is a stub returning `[]` for now — Task 6 replaces it with the real implementation. `extract/2`, `normalize_key/2`, and `key_changed/2` here supersede the versions from Task 4.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/live_react_props_diff_test.exs`
Expected: PASS.

- [ ] **Step 5: Run the full suite for regressions**

Run: `mix test`
Expected: PASS. (`live_react_test.exs`'s existing prop assertions still hold since non-diffed/initial-render props are unaffected in shape, only encoding changed from `Jason.encode!` to `Encoder.encode |> Patch.encode_object` — both produce the same JSON content for plain maps.)

- [ ] **Step 6: Commit**

```bash
git add lib/live_react.ex test/live_react_props_diff_test.exs
git commit -m "feat: compute props_diff via Jsonpatch and LiveReact.Encoder"
```

---

### Task 6: Stream diffing in `react/1`

**Files:**
- Modify: `lib/live_react.ex`
- Test: `test/live_react_streams_diff_test.exs`

**Interfaces:**
- Consumes: `LiveReact.Encoder.encode/1` (Task 2), `LiveReact.Patch.serialize/1` (Task 1).
- Produces: real `calculate_streams_diff/2` (replacing Task 5's stub), populating `data-streams-diff` for any `%Phoenix.LiveView.LiveStream{}` assign.

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule LiveReactStreamsDiffTest do
  use ExUnit.Case

  alias LiveReact.Test
  alias Phoenix.LiveView.LiveStream

  defp render_react_assigns(assigns) do
    rendered = LiveReact.react(assigns)
    html = rendered |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    Test.get_react(html)
  end

  defp assert_patches_equal(actual, expected) do
    actual_sorted = actual |> decode_patch() |> Enum.sort_by(&{&1["path"], &1["op"]})
    expected_sorted = Enum.sort_by(expected, &{&1["path"], &1["op"]})
    assert actual_sorted == expected_sorted
  end

  defp decode_patch(patch_list) do
    patch_list
    |> Enum.map(fn
      [op, path] -> %{"op" => op, "path" => path}
      [op, path, value] -> %{"op" => op, "path" => path, "value" => value}
    end)
    |> Enum.reject(&(&1["op"] == "test"))
  end

  defmodule StreamUser do
    @moduledoc false
    @derive LiveReact.Encoder
    defstruct [:id, :name, :age]
  end

  describe "LiveStream diff functionality" do
    test "initial render with LiveStream has stream diff in streams_diff" do
      users = [%StreamUser{id: 1, name: "Alice", age: 30}, %StreamUser{id: 2, name: "Bob", age: 25}]
      stream = LiveStream.new(:users, make_ref(), users, [])

      react = render_react_assigns(%{users: stream, __changed__: nil})

      expected_patches = [
        %{"op" => "replace", "path" => "/users", "value" => []},
        %{"op" => "upsert", "path" => "/users/-", "value" => %{"__dom_id" => "users-1", "age" => 30, "id" => 1, "name" => "Alice"}},
        %{"op" => "upsert", "path" => "/users/-", "value" => %{"__dom_id" => "users-2", "age" => 25, "id" => 2, "name" => "Bob"}}
      ]

      assert react.props == %{}
      assert_patches_equal(react.streams_diff, expected_patches)
    end

    test "inserting item to LiveStream creates upsert operation" do
      new_user = %StreamUser{id: 3, name: "Charlie", age: 28}
      stream = LiveStream.new(:users, make_ref(), [], [])
      stream = LiveStream.insert_item(stream, new_user, -1, nil, false)

      react =
        render_react_assigns(%{
          users: stream,
          __changed__: %{users: LiveStream.new(:users, make_ref(), [], [])}
        })

      assert_patches_equal(react.streams_diff, [
        %{"op" => "upsert", "path" => "/users/-", "value" => %{"id" => 3, "name" => "Charlie", "age" => 28, "__dom_id" => "users-3"}}
      ])
    end

    test "deleting item from LiveStream creates remove operation" do
      user_to_delete = %StreamUser{id: 2, name: "Bob", age: 25}
      stream = LiveStream.new(:users, make_ref(), [], [])
      stream = LiveStream.delete_item(stream, user_to_delete)

      react =
        render_react_assigns(%{
          users: stream,
          __changed__: %{users: LiveStream.new(:users, make_ref(), [], [])}
        })

      assert_patches_equal(react.streams_diff, [%{"op" => "remove", "path" => "/users/$$users-2"}])
    end

    test "resetting LiveStream creates replace operation" do
      stream = LiveStream.new(:users, make_ref(), [], [])
      stream = LiveStream.reset(stream)

      react =
        render_react_assigns(%{
          users: stream,
          __changed__: %{users: LiveStream.new(:users, make_ref(), [], [])}
        })

      assert_patches_equal(react.streams_diff, [%{"op" => "replace", "path" => "/users", "value" => []}])
    end

    test "stream with limit adds limit operation" do
      stream = LiveStream.new(:users, make_ref(), [], [])
      stream = LiveStream.insert_item(stream, %StreamUser{id: 1, name: "User", age: 1}, -1, 5, false)

      react =
        render_react_assigns(%{
          users: stream,
          __changed__: %{users: LiveStream.new(:users, make_ref(), [], [])}
        })

      decoded = decode_patch(react.streams_diff)
      limit_op = Enum.find(decoded, &(&1["op"] == "limit"))

      assert limit_op == %{"op" => "limit", "path" => "/users", "value" => 5}
    end

    test "stream insert with update_only flag creates replace operation" do
      stream = LiveStream.new(:users, make_ref(), [], [])
      stream = LiveStream.insert_item(stream, %StreamUser{id: 1, name: "Updated", age: 1}, -1, nil, true)

      react =
        render_react_assigns(%{
          users: stream,
          __changed__: %{users: LiveStream.new(:users, make_ref(), [], [])}
        })

      decoded = decode_patch(react.streams_diff)
      replace_op = Enum.find(decoded, &(&1["op"] == "replace" && String.contains?(&1["path"], "$$")))

      assert replace_op["value"]["name"] == "Updated"
    end

    test "LiveStream assigns do not appear in props" do
      stream = LiveStream.new(:users, make_ref(), [], [])

      react = render_react_assigns(%{users: stream, title: "Page", __changed__: nil})

      assert react.props == %{"title" => "Page"}
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/live_react_streams_diff_test.exs`
Expected: FAIL — `calculate_streams_diff/2` is still the Task 5 stub returning `[]`.

- [ ] **Step 3: Implement real stream diffing**

In `lib/live_react.ex`, replace the stub:

```elixir
defp calculate_streams_diff(_streams, _initial), do: []
```

with:

```elixir
# Generates JSON patch operations for LiveStream changes.
# Handles insertions and deletions for Phoenix LiveView streams.
defp calculate_streams_diff(streams, initial)

defp calculate_streams_diff(streams, true) do
  # for initial render, we want to reset all streams, and then apply the diffs
  init = Enum.map(streams, fn {k, _} -> %{op: "replace", path: "/#{k}", value: []} end)
  diffs = Enum.flat_map(streams, fn {k, stream} -> generate_stream_patches(k, stream) end)
  init ++ diffs
end

defp calculate_streams_diff(streams, false) do
  streams
  |> Enum.flat_map(fn {k, stream} -> generate_stream_patches(k, stream) end)
  |> then(fn diff -> [%{op: "test", path: "", value: :rand.uniform(10_000_000)} | diff] end)
end

# Generates JSON patch operations for a single LiveStream's changes.
defp generate_stream_patches(stream_name, %LiveStream{} = stream) do
  patches = []

  patches =
    if stream.reset?,
      do: [%{op: "replace", path: "/#{stream_name}", value: []} | patches],
      else: patches

  patches =
    Enum.reduce(stream.deletes, patches, fn dom_id, patches ->
      [%{op: "remove", path: "/#{stream_name}/$$#{dom_id}"} | patches]
    end)

  # Reversed - inserts at -1 should be correctly ordered, inserts at 0 should be reversed
  # see https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#stream/4 :at option
  stream.inserts
  |> Enum.reverse()
  |> Enum.reduce(patches, fn {dom_id, at, item, limit, update_only}, patches ->
    item = Map.put(Encoder.encode(item), :__dom_id, dom_id)

    patches =
      if update_only,
        do: [%{op: "replace", path: "/#{stream_name}/$$#{dom_id}", value: item} | patches],
        else: [%{op: "upsert", path: "/#{stream_name}/#{if at == -1, do: "-", else: at}", value: item} | patches]

    if limit,
      do: [%{op: "limit", path: "/#{stream_name}", value: limit} | patches],
      else: patches
  end)
  |> Enum.reverse()
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/live_react_streams_diff_test.exs`
Expected: PASS.

- [ ] **Step 5: Run the full suite for regressions**

Run: `mix test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/live_react.ex test/live_react_streams_diff_test.exs
git commit -m "feat: compute streams_diff from Phoenix.LiveView.LiveStream assigns"
```

---

### Task 7: `LiveReact.Test` updates

**Files:**
- Modify: `lib/live_react/test.ex`
- Test: `test/live_react_test_helper_test.exs`

**Interfaces:**
- Consumes: `LiveReact.Patch.decode_object/1` + `deserialize/1` (Task 1).
- Produces: `LiveReact.Test.get_react/2` now returns `:props_diff`, `:streams_diff`, `:use_diff` keys in addition to the existing ones. Later manual/example verification and any future test suites rely on this shape.

- [ ] **Step 1: Write the failing test**

```elixir
defmodule LiveReactTestHelperTest do
  use ExUnit.Case

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias LiveReact.Test

  def component(assigns) do
    ~H"""
    <.react name="TestComponent" title="Hello" />
    """
  end

  test "get_react exposes props_diff, streams_diff, and use_diff" do
    html = render_component(&component/1)
    react = Test.get_react(html)

    assert react.props == %{"title" => "Hello"}
    assert react.use_diff == true
    assert react.props_diff == []
    assert react.streams_diff == []
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mix test test/live_react_test_helper_test.exs`
Expected: FAIL — `react.props_diff`/`react.streams_diff`/`react.use_diff` are `KeyError`, and `react.props` currently raises since `data-props` is no longer plain JSON (it's caret-escaped via `Patch.encode_object`, so `Jason.decode!/1` fails on it).

- [ ] **Step 3: Update `lib/live_react/test.ex`**

Replace the body of `get_react/2` (the `is_binary` clause) with:

```elixir
def get_react(html, opts) when is_binary(html) do
  if Code.ensure_loaded?(Floki) do
    react =
      html
      |> Floki.parse_document!()
      |> Floki.find("[phx-hook='ReactHook']")
      |> find_component!(opts)

    %{
      props: LiveReact.Patch.decode_object(attr(react, "data-props")),
      component: attr(react, "data-name"),
      id: attr(react, "id"),
      slots: extract_base64_slots(attr(react, "data-slots")),
      ssr: if(is_nil(attr(react, "data-ssr")), do: false, else: true),
      use_diff: attr(react, "data-use-diff") == "true",
      class: attr(react, "class"),
      props_diff: LiveReact.Patch.deserialize(attr(react, "data-props-diff") || ""),
      streams_diff: LiveReact.Patch.deserialize(attr(react, "data-streams-diff") || "")
    }
  else
    raise "Floki is not installed. Add {:floki, \">= 0.30.0\", only: :test} to your dependencies to use LiveReact.Test"
  end
end
```

Add to the moduledoc, after the existing `## Examples` section:

```markdown
  ## Configuration

  ### enable_props_diff

  When set to `false` in your config, LiveReact will always send full props and not send diffs.
  This is useful for testing scenarios where you need to inspect the complete props state
  rather than just the changes.

  ```elixir
  # config/test.exs
  config :live_react,
    enable_props_diff: false
  ```

  When disabled, the `props` field returned by `get_react/2` will always contain
  the complete props state, making it easier to write comprehensive tests that verify the
  full component state rather than just the incremental changes.
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `mix test test/live_react_test_helper_test.exs`
Expected: PASS.

- [ ] **Step 5: Run the full suite for regressions**

Run: `mix test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/live_react/test.ex test/live_react_test_helper_test.exs
git commit -m "feat: expose props_diff/streams_diff/use_diff from LiveReact.Test"
```

---

### Task 8: JS test infrastructure (Vitest)

**Files:**
- Modify: `package.json` (repo root)
- Create: `vitest.config.js` (repo root)

**Interfaces:**
- Consumes: nothing.
- Produces: `npm test` runs Vitest against `assets/**/*.test.js`. Tasks 9-11 depend on this being in place before they can run their JS tests.

- [ ] **Step 1: Add dev dependencies and scripts to `package.json`**

```json
{
  "name": "live_react",
  "version": "0.1.0",
  "description": "E2E reactivity from React and LiveView",
  "license": "MIT",
  "module": "./assets/js/live_react/index.js",
  "exports": {
    ".": {
      "import": "./assets/js/live_react/index.mjs",
      "types": "./assets/js/live_react/index.d.mts"
    },
    "./server": "./assets/js/live_react/server.mjs",
    "./vite-plugin": "./assets/js/live_react/vite-plugin.js"
  },
  "author": "Baptiste Chaleil <hello@mrdotb.com>",
  "repository": {
    "type": "git",
    "url": "git://github.com/mrdotb/live_react.git"
  },
  "files": [
    "README.MD",
    "LICENSE.md",
    "package.json",
    "assets/js/live_react/*"
  ],
  "devDependencies": {
    "jsdom": "^26.1.0",
    "prettier": "^3.3.2",
    "vitest": "^3.2.4"
  },
  "scripts": {
    "format": "npx prettier --write .",
    "test": "vitest run",
    "test:watch": "vitest --watch"
  }
}
```

- [ ] **Step 2: Create `vitest.config.js`**

```js
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "jsdom",
    globals: true,
    include: ["assets/**/*.test.js"],
  },
});
```

- [ ] **Step 3: Install and verify the runner boots with zero tests**

Run: `npm install && npm test`
Expected: Vitest reports "No test files found" (or passes with 0 test files) — confirms the runner and config are wired correctly before real test files exist.

- [ ] **Step 4: Commit**

```bash
git add package.json package-lock.json vitest.config.js
git commit -m "chore: add vitest test runner for client-side JS"
```

---

### Task 9: `compactPatch.js`

**Files:**
- Create: `assets/js/live_react/compactPatch.js`
- Test: `assets/js/live_react/compactPatch.test.js`

**Interfaces:**
- Consumes: nothing (pure decode logic).
- Produces: `decodeCompactPatch(payload: string | null): Array<{op, path, value?}>`, `decodeCompactJson(value: string): any`. Tasks 10 and 11 import both.

- [ ] **Step 1: Write the failing tests**

```js
import { describe, expect, it } from "vitest";
import { decodeCompactPatch } from "./compactPatch";

describe("decodeCompactPatch", () => {
  it("decodes scalar add, replace, remove, and nonce operations", () => {
    expect(decodeCompactPatch("n123r6:/countn1:6a8:/items/3s1:dd8:/items/0")).toEqual([
      { op: "replace", path: "/count", value: 6 },
      { op: "add", path: "/items/3", value: "d" },
      { op: "remove", path: "/items/0" },
    ]);
  });

  it("decodes caret-encoded JSON values", () => {
    expect(decodeCompactPatch("a5:/rowsJ25:{^id^:3,^name^:^Charlie^}")).toEqual([
      { op: "add", path: "/rows", value: { id: 3, name: "Charlie" } },
    ]);
  });

  it("decodes escaped caret JSON values", () => {
    expect(decodeCompactPatch("a5:/metaJ27:{^tilde^:^~~^,^caret^:^~^^}")).toEqual([
      { op: "add", path: "/meta", value: { tilde: "~", caret: "^" } },
    ]);
  });

  it("uses JavaScript string lengths for strings and paths", () => {
    expect(decodeCompactPatch("r14:/profile/na.mes6:zażółćr6:/emojis2:🚀")).toEqual([
      { op: "replace", path: "/profile/na.me", value: "zażółć" },
      { op: "replace", path: "/emoji", value: "🚀" },
    ]);
  });

  it("decodes null, booleans, floats, upsert, and limit", () => {
    expect(decodeCompactPatch("r6:/titlezu6:/itemsJ8:{^id^:1}l6:/itemsn2:-3r5:/flagb0r6:/pricen4:22.5")).toEqual([
      { op: "replace", path: "/title", value: null },
      { op: "upsert", path: "/items", value: { id: 1 } },
      { op: "limit", path: "/items", value: -3 },
      { op: "replace", path: "/flag", value: false },
      { op: "replace", path: "/price", value: 22.5 },
    ]);
  });

  it("returns an empty array for a null or empty payload", () => {
    expect(decodeCompactPatch(null)).toEqual([]);
    expect(decodeCompactPatch("")).toEqual([]);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm test -- compactPatch`
Expected: FAIL — module `./compactPatch` does not exist.

- [ ] **Step 3: Implement `compactPatch.js`**

```js
export const decodeCompactPatch = (payload) => {
  if (!payload) return [];

  const operations = [];
  let offset = 0;

  while (offset < payload.length) {
    const code = payload[offset++];

    if (code === "n") {
      offset = skipDigits(payload, offset);
      continue;
    }

    const op = opFromCode(code);
    const pathLength = readLength(payload, offset);
    offset = pathLength.offset;

    const path = payload.slice(offset, offset + pathLength.value);
    offset += pathLength.value;

    if (op === "remove") {
      operations.push({ op, path });
      continue;
    }

    const tag = payload[offset++];

    if (tag === "z") {
      operations.push({ op, path, value: null });
      continue;
    }

    if (tag === "b") {
      operations.push({ op, path, value: payload[offset++] === "1" });
      continue;
    }

    const valueLength = readLength(payload, offset);
    offset = valueLength.offset;

    const rawValue = payload.slice(offset, offset + valueLength.value);
    offset += valueLength.value;

    if (tag === "n") {
      operations.push({ op, path, value: Number(rawValue) });
    } else if (tag === "s") {
      operations.push({ op, path, value: rawValue });
    } else if (tag === "J") {
      operations.push({ op, path, value: decodeCompactJson(rawValue) });
    } else {
      throw new Error(`Unknown LiveReact patch value tag: ${tag}`);
    }
  }

  return operations;
};

const opFromCode = (code) => {
  switch (code) {
    case "a":
      return "add";
    case "d":
      return "remove";
    case "r":
      return "replace";
    case "u":
      return "upsert";
    case "l":
      return "limit";
    default:
      throw new Error(`Unknown LiveReact patch operation code: ${code}`);
  }
};

const readLength = (payload, offset) => {
  let value = 0;
  let hasDigits = false;

  while (offset < payload.length) {
    const code = payload.charCodeAt(offset);
    if (code < 48 || code > 57) break;
    value = value * 10 + code - 48;
    offset++;
    hasDigits = true;
  }

  if (!hasDigits || payload[offset] !== ":") throw new Error("Invalid LiveReact patch length prefix");
  return { value, offset: offset + 1 };
};

const skipDigits = (payload, offset) => {
  while (offset < payload.length) {
    const code = payload.charCodeAt(offset);
    if (code < 48 || code > 57) break;
    offset++;
  }

  return offset;
};

export const decodeCompactJson = (value) => {
  return JSON.parse(
    value.replace(/~~|~\^|\^/g, (match) => {
      if (match === "~~") return "~";
      if (match === "~^") return "^";
      return '"';
    }),
  );
};
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm test -- compactPatch`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add assets/js/live_react/compactPatch.js assets/js/live_react/compactPatch.test.js
git commit -m "feat: add compactPatch decoder for LiveReact patch wire format"
```

---

### Task 10: `jsonPatch.js` with copy-on-write

**Files:**
- Create: `assets/js/live_react/jsonPatch.js`
- Test: `assets/js/live_react/jsonPatch.test.js`

**Interfaces:**
- Consumes: nothing (pure logic module).
- Produces: `applyPatch(document, patch): document` — applies a batch of patch operations, cloning (shallow) the value at each touched top-level key of `document` on first touch, mutating the clone in place, and leaving untouched keys' values byte-for-byte reference-identical to before the call. `getValueByPointer`, `applyOperation` also exported for direct use/testing. Task 11 (`hooks.js`) is the consumer.

- [ ] **Step 1: Write the failing tests**

```js
import { describe, it, expect } from "vitest";
import { getValueByPointer, applyOperation, applyPatch } from "./jsonPatch";

describe("getValueByPointer", () => {
  const testDoc = {
    foo: "bar",
    baz: [1, 2, 3],
    nested: { key: "value" },
  };

  it("returns the root document for an empty pointer", () => {
    expect(getValueByPointer(testDoc, "")).toBe(testDoc);
  });

  it("gets a simple property", () => {
    expect(getValueByPointer(testDoc, "/foo")).toBe("bar");
  });

  it("gets an array element by index", () => {
    expect(getValueByPointer(testDoc, "/baz/1")).toBe(2);
  });

  it("gets the last array element with -", () => {
    expect(getValueByPointer(testDoc, "/baz/-")).toBe(3);
  });

  it("gets a nested property", () => {
    expect(getValueByPointer(testDoc, "/nested/key")).toBe("value");
  });
});

describe("applyOperation", () => {
  it("adds a property to an object", () => {
    const doc = { foo: "bar" };
    applyOperation(doc, { op: "add", path: "/baz", value: "qux" });
    expect(doc).toEqual({ foo: "bar", baz: "qux" });
  });

  it("replaces a property in an object", () => {
    const doc = { foo: "bar" };
    applyOperation(doc, { op: "replace", path: "/foo", value: "baz" });
    expect(doc).toEqual({ foo: "baz" });
  });

  it("removes a property from an object", () => {
    const doc = { foo: "bar", baz: "qux" };
    applyOperation(doc, { op: "remove", path: "/foo" });
    expect(doc).toEqual({ baz: "qux" });
  });

  it("adds an element to an array at a specific index", () => {
    const doc = { arr: [1, 2, 3] };
    applyOperation(doc, { op: "add", path: "/arr/1", value: "new" });
    expect(doc).toEqual({ arr: [1, "new", 2, 3] });
  });

  it("adds an element to the end of an array with -", () => {
    const doc = { arr: [1, 2, 3] };
    applyOperation(doc, { op: "add", path: "/arr/-", value: "new" });
    expect(doc).toEqual({ arr: [1, 2, 3, "new"] });
  });

  it("removes an element from an array", () => {
    const doc = { arr: [1, 2, 3] };
    applyOperation(doc, { op: "remove", path: "/arr/1" });
    expect(doc).toEqual({ arr: [1, 3] });
  });

  it("resolves $$dom_id in array paths for upsert (update)", () => {
    const doc = { rows: [{ __dom_id: "a", v: 1 }, { __dom_id: "b", v: 2 }] };
    applyOperation(doc, { op: "upsert", path: "/rows/-", value: { __dom_id: "a", v: 99 } });
    expect(doc.rows).toEqual([{ __dom_id: "a", v: 99 }, { __dom_id: "b", v: 2 }]);
  });

  it("resolves $$dom_id in array paths for upsert (insert)", () => {
    const doc = { rows: [{ __dom_id: "a", v: 1 }] };
    applyOperation(doc, { op: "upsert", path: "/rows/-", value: { __dom_id: "c", v: 3 } });
    expect(doc.rows).toEqual([{ __dom_id: "a", v: 1 }, { __dom_id: "c", v: 3 }]);
  });

  it("removes an array element by $$dom_id", () => {
    const doc = { rows: [{ __dom_id: "a" }, { __dom_id: "b" }] };
    applyOperation(doc, { op: "remove", path: "/rows/$$a" });
    expect(doc.rows).toEqual([{ __dom_id: "b" }]);
  });

  it("applies limit by trimming from the end for positive values", () => {
    const doc = { rows: [1, 2, 3, 4] };
    applyOperation(doc, { op: "limit", path: "/rows", value: 2 });
    expect(doc.rows).toEqual([1, 2]);
  });

  it("applies limit by trimming from the start for negative values", () => {
    const doc = { rows: [1, 2, 3, 4] };
    applyOperation(doc, { op: "limit", path: "/rows", value: -2 });
    expect(doc.rows).toEqual([3, 4]);
  });
});

describe("applyPatch copy-on-write", () => {
  it("gives a fresh array reference for a touched top-level key", () => {
    const original = { users: [{ __dom_id: "a", name: "Alice" }] };
    const usersRefBefore = original.users;

    const result = applyPatch(original, [
      { op: "upsert", path: "/users/-", value: { __dom_id: "b", name: "Bob" } },
    ]);

    expect(result.users).not.toBe(usersRefBefore);
    expect(result.users).toEqual([
      { __dom_id: "a", name: "Alice" },
      { __dom_id: "b", name: "Bob" },
    ]);
  });

  it("keeps untouched top-level keys reference-identical", () => {
    const original = { users: [{ __dom_id: "a" }], posts: [{ __dom_id: "p1" }] };
    const postsRefBefore = original.posts;

    const result = applyPatch(original, [{ op: "remove", path: "/users/$$a" }]);

    expect(result.posts).toBe(postsRefBefore);
  });

  it("keeps unaffected items reference-identical while replacing changed ones", () => {
    const alice = { __dom_id: "a", name: "Alice" };
    const bob = { __dom_id: "b", name: "Bob" };
    const original = { users: [alice, bob] };

    const result = applyPatch(original, [
      { op: "replace", path: "/users/$$b", value: { __dom_id: "b", name: "New Bob" } },
    ]);

    expect(result.users[0]).toBe(alice);
    expect(result.users[1]).not.toBe(bob);
    expect(result.users[1]).toEqual({ __dom_id: "b", name: "New Bob" });
  });

  it("only clones a key once across multiple ops in the same batch", () => {
    const original = { users: [{ __dom_id: "a" }] };

    const result = applyPatch(original, [
      { op: "upsert", path: "/users/-", value: { __dom_id: "b" } },
      { op: "upsert", path: "/users/-", value: { __dom_id: "c" } },
    ]);

    expect(result.users.map((u) => u.__dom_id)).toEqual(["a", "b", "c"]);
  });

  it("mutates and returns the same document object (bag identity is stable)", () => {
    const original = { users: [] };
    const result = applyPatch(original, [{ op: "upsert", path: "/users/-", value: { __dom_id: "a" } }]);
    expect(result).toBe(original);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm test -- jsonPatch`
Expected: FAIL — module `./jsonPatch` does not exist.

- [ ] **Step 3: Implement `jsonPatch.js`**

```js
function unescapePathComponent(path) {
  return path.replace(/~1/g, "/").replace(/~0/g, "~");
}

function resolvePathComponent(component, arrayObj) {
  if (!component.startsWith("$$")) {
    return component;
  }

  const targetId = component.substring(2);
  const index = arrayObj.findIndex((item) => item && typeof item === "object" && item.__dom_id == targetId);

  if (index === -1) {
    console.warn(`JSON Patch: Item with __dom_id "${targetId}" not found in array, skipping operation`);
    return null;
  }

  return index.toString();
}

function readPathSegment(path, start, end) {
  const segment = path.slice(start, end);
  return segment.indexOf("~") === -1 ? segment : unescapePathComponent(segment);
}

function resolveArrayIndex(key, arrayObj, allowAppend) {
  if (key.startsWith("$$")) {
    const resolved = resolvePathComponent(key, arrayObj);
    return resolved === null ? null : parseInt(resolved, 10);
  }

  if (key === "-") return allowAppend ? arrayObj.length : arrayObj.length - 1;
  return parseInt(key, 10);
}

export function getValueByPointer(document, pointer) {
  if (pointer === "") return document;

  const keys = pointer.split("/").slice(1);
  let obj = document;

  for (const key of keys) {
    let resolvedKey = key.indexOf("~") !== -1 ? unescapePathComponent(key) : key;

    if (Array.isArray(obj)) {
      if (resolvedKey.startsWith("$$")) {
        const resolved = resolvePathComponent(resolvedKey, obj);
        if (resolved === null) return undefined;
        resolvedKey = resolved;
      }
      obj = obj[resolvedKey === "-" ? obj.length - 1 : parseInt(resolvedKey, 10)];
    } else {
      obj = obj[resolvedKey];
    }
  }

  return obj;
}

/**
 * Apply a single patch operation on a JSON document in-place.
 */
export function applyOperation(document, operation) {
  return applyPatchOperation(document, operation.op, operation.path, operation.value);
}

function applyPatchOperation(document, op, path, value) {
  if (path === "") {
    switch (op) {
      case "add":
      case "replace":
        return value;
      case "test":
        return document;
      case "remove":
        return null;
    }
  }

  let obj = document;
  let segmentStart = 1;

  while (true) {
    const segmentEnd = path.indexOf("/", segmentStart);
    if (segmentEnd === -1) break;

    const key = readPathSegment(path, segmentStart, segmentEnd);

    if (Array.isArray(obj)) {
      const index = resolveArrayIndex(key, obj, false);
      if (index === null) return document;
      obj = obj[index];
    } else {
      obj = obj[key];
    }

    segmentStart = segmentEnd + 1;
  }

  const unescapedKey = readPathSegment(path, segmentStart, path.length);

  if (Array.isArray(obj)) {
    const resolvedIndex = resolveArrayIndex(unescapedKey, obj, true);
    if (resolvedIndex === null) return document;
    const index = resolvedIndex;

    switch (op) {
      case "add":
        obj.splice(index, 0, value);
        break;
      case "remove":
        obj.splice(index, 1);
        break;
      case "replace":
        obj[index] = value;
        break;
      case "upsert":
        if (value && typeof value === "object" && "__dom_id" in value) {
          const existingIndex = obj.findIndex(
            (item) => item && typeof item === "object" && item.__dom_id === value.__dom_id,
          );

          if (existingIndex !== -1) {
            obj[existingIndex] = value;
          } else {
            obj.splice(index, 0, value);
          }
        } else {
          obj.splice(index, 0, value);
        }
        break;
      case "test":
        break;
      case "limit":
        if (value >= 0) {
          if (value < obj.length) obj.splice(value);
        } else {
          const keepCount = Math.abs(value);
          if (keepCount < obj.length) obj.splice(0, obj.length - keepCount);
        }
        break;
    }
  } else {
    switch (op) {
      case "add":
      case "replace":
        obj[unescapedKey] = value;
        break;
      case "remove":
        delete obj[unescapedKey];
        break;
      case "test":
        break;
      case "limit":
        const targetArray = obj[unescapedKey];
        if (Array.isArray(targetArray)) {
          if (value >= 0) {
            if (value < targetArray.length) targetArray.splice(value);
          } else {
            const keepCount = Math.abs(value);
            if (keepCount < targetArray.length) targetArray.splice(0, targetArray.length - keepCount);
          }
        }
        break;
    }
  }

  return document;
}

function cloneShallow(value) {
  if (Array.isArray(value)) return value.slice();
  if (value && typeof value === "object") return { ...value };
  return value;
}

function firstPathSegment(path) {
  const end = path.indexOf("/", 1);
  const raw = end === -1 ? path.slice(1) : path.slice(1, end);
  return raw.indexOf("~") === -1 ? raw : unescapePathComponent(raw);
}

/**
 * Apply a sequence of patch operations to a document.
 *
 * Copy-on-write: the value at each patch's first path segment (e.g. `users`
 * in `/users/-`) is shallow-cloned the first time an operation in this batch
 * touches it, so React sees a fresh reference for anything that actually
 * changed while untouched keys (and untouched items within a touched array,
 * since per-item replace/upsert already assign fresh item references rather
 * than mutating items in place) keep their prior identity.
 */
export function applyPatch(document, patch) {
  let result = document;
  const touchedKeys = new Set();

  for (const operation of patch) {
    if (operation.path === "") {
      result = applyOperation(result, operation);
      continue;
    }

    const key = firstPathSegment(operation.path);

    if (!touchedKeys.has(key)) {
      touchedKeys.add(key);
      result[key] = cloneShallow(result[key]);
    }

    applyOperation(result, operation);
  }

  return result;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm test -- jsonPatch`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add assets/js/live_react/jsonPatch.js assets/js/live_react/jsonPatch.test.js
git commit -m "feat: add copy-on-write patch application for React"
```

---

### Task 11: `hooks.js` — persistent props/streams state

**Files:**
- Modify: `assets/js/live_react/hooks.js`
- Create: `assets/js/live_react/tests/helpers.js`
- Test: `assets/js/live_react/hooks.test.js`

**Interfaces:**
- Consumes: `decodeCompactJson`, `decodeCompactPatch` (Task 9); `applyPatch` (Task 10).
- Produces: `getHooks(components)` behaves as before for consumers, but the `ReactHook` now merges `data-streams-diff` (always) and either `data-props-diff` or full `data-props` (depending on `data-use-diff`) into persistent `_props`/`_streams` state across `mounted`/`updated`/`reconnected`.

- [ ] **Step 1: Create the mock hook helper**

```js
// assets/js/live_react/tests/helpers.js
import { vi } from "vitest";

let mockIdCounter = 0;

export const createMockLiveViewHook = (elementAttributes = {}) => {
  const id = elementAttributes.id || `mock-${++mockIdCounter}`;
  const attributes = { ...elementAttributes };

  const mockElement = {
    id,
    getAttribute: vi.fn((name) => (name in attributes ? attributes[name] : null)),
    setAttribute: vi.fn((name, value) => {
      attributes[name] = value;
    }),
    hasAttribute: vi.fn((name) => name in attributes),
    hasChildNodes: vi.fn(() => false),
  };

  return {
    el: mockElement,
    pushEvent: vi.fn(),
    pushEventTo: vi.fn(),
    handleEvent: vi.fn(),
    removeHandleEvent: vi.fn(),
    upload: vi.fn(),
    uploadTo: vi.fn(),
  };
};
```

- [ ] **Step 2: Write the failing tests**

```js
// assets/js/live_react/hooks.test.js
import { describe, it, expect, vi, beforeEach } from "vitest";
import { createMockLiveViewHook } from "./tests/helpers";

const renderMock = vi.fn();
const rootMock = { render: renderMock, unmount: vi.fn() };

vi.mock("react-dom/client", () => ({
  default: {
    createRoot: vi.fn(() => rootMock),
    hydrateRoot: vi.fn(() => rootMock),
  },
}));

const TestComponent = () => null;

function lastRenderedProps() {
  // The rendered tree is <LiveReactProvider {...hooks}><TestComponent {...props} /></LiveReactProvider>
  const tree = renderMock.mock.calls.at(-1)[0];
  return tree.props.children.props;
}

// Minimal test-only encoder mirroring LiveReact.Patch.serialize/1 and
// LiveReact.Patch.encode_object/1, so fixtures can't drift from hand-typed
// wire strings. Exercised indirectly by decodeCompactPatch/decodeCompactJson
// (already unit-tested against real Elixir-produced fixtures in Task 9).
const OP_CODES = { add: "a", remove: "d", replace: "r", upsert: "u", limit: "l" };

function encodeValue(value) {
  if (value === null) return "z";
  if (value === true) return "b1";
  if (value === false) return "b0";
  if (typeof value === "number") {
    const s = String(value);
    return `n${s.length}:${s}`;
  }
  if (typeof value === "string") return `s${value.length}:${value}`;
  const json = JSON.stringify(value).replace(/"/g, "^");
  return `J${json.length}:${json}`;
}

function encodePatch(ops) {
  return ops
    .map(([op, path, value]) => {
      const prefix = `${OP_CODES[op]}${path.length}:${path}`;
      return op === "remove" ? prefix : prefix + encodeValue(value);
    })
    .join("");
}

function encodeProps(props) {
  return JSON.stringify(props).replace(/"/g, "^");
}

describe("ReactHook", () => {
  let getHooks;
  let ReactHook;

  beforeEach(async () => {
    vi.resetModules();
    renderMock.mockClear();
    ({ getHooks } = await import("./hooks"));
    ({ ReactHook } = getHooks({ TestComponent }));
  });

  it("merges base props and streams on mount", () => {
    const hook = createMockLiveViewHook({
      "data-name": "TestComponent",
      "data-props": encodeProps({ title: "Hello" }),
      "data-streams-diff": encodePatch([
        ["replace", "/users", []],
        ["upsert", "/users/-", { __dom_id: "u1" }],
      ]),
    });

    ReactHook.mounted.call(hook);

    const props = lastRenderedProps();
    expect(props.title).toBe("Hello");
    expect(props.users).toEqual([{ __dom_id: "u1" }]);
  });

  it("applies props_diff on update when data-use-diff is true", () => {
    const hook = createMockLiveViewHook({
      "data-name": "TestComponent",
      "data-props": encodeProps({ title: "Hello" }),
      "data-use-diff": "true",
    });

    ReactHook.mounted.call(hook);

    hook.el.getAttribute.mockImplementation((name) => {
      if (name === "data-use-diff") return "true";
      if (name === "data-props-diff") return encodePatch([["replace", "/title", "World"]]);
      if (name === "data-streams-diff") return null;
      return null;
    });

    ReactHook.updated.call(hook);

    expect(lastRenderedProps().title).toBe("World");
  });

  it("replaces props wholesale on update when data-use-diff is false", () => {
    const hook = createMockLiveViewHook({
      "data-name": "TestComponent",
      "data-props": encodeProps({ title: "Hello" }),
      "data-use-diff": "false",
    });

    ReactHook.mounted.call(hook);

    hook.el.getAttribute.mockImplementation((name) => {
      if (name === "data-use-diff") return "false";
      if (name === "data-props") return encodeProps({ title: "Replaced" });
      if (name === "data-streams-diff") return null;
      return null;
    });

    ReactHook.updated.call(hook);

    expect(lastRenderedProps().title).toBe("Replaced");
  });

  it("accumulates stream inserts across updates without losing prior items", () => {
    const hook = createMockLiveViewHook({
      "data-name": "TestComponent",
      "data-props": encodeProps({}),
      "data-streams-diff": encodePatch([
        ["replace", "/users", []],
        ["upsert", "/users/-", { __dom_id: "u1" }],
      ]),
    });

    ReactHook.mounted.call(hook);

    hook.el.getAttribute.mockImplementation((name) => {
      if (name === "data-use-diff") return "true";
      if (name === "data-props-diff") return null;
      if (name === "data-streams-diff") return encodePatch([["upsert", "/users/-", { __dom_id: "u2" }]]);
      return null;
    });

    ReactHook.updated.call(hook);

    expect(lastRenderedProps().users).toEqual([{ __dom_id: "u1" }, { __dom_id: "u2" }]);
  });

  it("reconnected() re-applies props and streams diffs like updated()", () => {
    const hook = createMockLiveViewHook({
      "data-name": "TestComponent",
      "data-props": encodeProps({ title: "Hello" }),
      "data-streams-diff": encodePatch([
        ["replace", "/users", []],
        ["upsert", "/users/-", { __dom_id: "u1" }],
      ]),
    });

    ReactHook.mounted.call(hook);

    hook.el.getAttribute.mockImplementation((name) => {
      if (name === "data-use-diff") return "true";
      if (name === "data-props-diff") return null;
      if (name === "data-streams-diff") return encodePatch([["upsert", "/users/-", { __dom_id: "u2" }]]);
      return null;
    });

    ReactHook.reconnected.call(hook);

    expect(lastRenderedProps().users).toEqual([{ __dom_id: "u1" }, { __dom_id: "u2" }]);
  });
});
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `npm test -- hooks`
Expected: FAIL — `ReactHook.reconnected` is undefined, and props/streams merging doesn't happen yet (current `hooks.js` re-parses `data-props` wholesale every render and has no stream handling).

- [ ] **Step 4: Update `hooks.js`**

```js
import React from "react";
import ReactDOM from "react-dom/client";
import { getComponentTree } from "./utils";
import { decodeCompactJson, decodeCompactPatch } from "./compactPatch";
import { applyPatch } from "./jsonPatch";

function getAttributeJson(el, attributeName) {
  const data = el.getAttribute(attributeName);
  return data ? JSON.parse(data) : {};
}

function getDiff(el, attributeName) {
  return decodeCompactPatch(el.getAttribute(attributeName));
}

function getBaseProps(el) {
  const data = el.getAttribute("data-props");
  return data ? decodeCompactJson(data) : {};
}

function getChildren(hook) {
  const dataSlots = getAttributeJson(hook.el, "data-slots");

  if (!dataSlots?.default) {
    return [];
  }

  return [
    React.createElement("div", {
      dangerouslySetInnerHTML: { __html: atob(dataSlots.default).trim() },
    }),
  ];
}

function getProps(hook) {
  return {
    ...hook._props,
    ...hook._streams,
    pushEvent: hook.pushEvent.bind(hook),
    pushEventTo: hook.pushEventTo.bind(hook),
    handleEvent: hook.handleEvent.bind(hook),
    removeHandleEvent: hook.removeHandleEvent.bind(hook),
    upload: hook.upload.bind(hook),
    uploadTo: hook.uploadTo.bind(hook),
  };
}

function refreshStreams(hook) {
  hook._streams = applyPatch(hook._streams, getDiff(hook.el, "data-streams-diff"));
}

function refreshProps(hook) {
  if (hook.el.getAttribute("data-use-diff") === "true") {
    hook._props = applyPatch(hook._props, getDiff(hook.el, "data-props-diff"));
  } else {
    hook._props = getBaseProps(hook.el);
  }
}

export function getHooks(components) {
  const ReactHook = {
    _render() {
      const tree = getComponentTree(this._Component, getProps(this), getChildren(this));
      this._root.render(tree);
    },
    mounted() {
      const componentName = this.el.getAttribute("data-name");
      if (!componentName) {
        throw new Error("Component name must be provided");
      }

      this._Component = components[componentName];
      this._props = getBaseProps(this.el);
      this._streams = {};
      refreshStreams(this);

      const isSSR = this.el.hasAttribute("data-ssr");

      if (isSSR) {
        const tree = getComponentTree(this._Component, getProps(this), getChildren(this));
        this._root = ReactDOM.hydrateRoot(this.el, tree);
      } else {
        this._root = ReactDOM.createRoot(this.el);
        this._render();
      }
    },
    updated() {
      if (this._root) {
        refreshProps(this);
        refreshStreams(this);
        this._render();
      }
    },
    reconnected() {
      if (this._root) {
        refreshProps(this);
        refreshStreams(this);
        this._render();
      }
    },
    destroyed() {
      if (this._root) {
        window.addEventListener("phx:page-loading-stop", () => this._root.unmount(), { once: true });
      }
    },
  };

  return { ReactHook };
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `npm test -- hooks`
Expected: PASS.

- [ ] **Step 6: Run the full JS suite for regressions**

Run: `npm test`
Expected: PASS (all of `compactPatch.test.js`, `jsonPatch.test.js`, `hooks.test.js` green).

- [ ] **Step 7: Commit**

```bash
git add assets/js/live_react/hooks.js assets/js/live_react/hooks.test.js assets/js/live_react/tests/helpers.js
git commit -m "feat: apply props/streams diffs with persistent hook state, add reconnected()"
```

---

### Task 12: CHANGELOG entry

**Files:**
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks — documentation only.

- [ ] **Step 1: Read the top of `CHANGELOG.md` to match its existing format**

Run: `head -n 30 CHANGELOG.md`

- [ ] **Step 2: Add an "Unreleased" entry above the most recent version heading**

Add a section (matching whatever heading style the existing file uses, typically `## [Unreleased]` or a new version heading per this project's `git_ops`-managed convention) with:

```markdown
### Breaking Changes

- `data-props` is now encoded via the new `LiveReact.Encoder` protocol instead
  of `Jason.Encoder`. Struct props must now `@derive LiveReact.Encoder` (or
  implement it explicitly) — plain maps are unaffected. See
  `LiveReact.Encoder` moduledoc for migration examples.

### Features

- Props are now diffed and sent incrementally over `data-props-diff` instead
  of being fully re-sent on every update (`config :live_react,
  enable_props_diff: true` by default; opt out globally with `false` or
  per-component with `diff={false}`).
- Added support for `Phoenix.LiveView.stream/3,4` assigns: any
  `%Phoenix.LiveView.LiveStream{}` value passed as a prop is now
  automatically diffed and delivered over `data-streams-diff`.
```

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog entry for props diffing and stream support"
```

---

### Task 13: Example app demo (manual verification)

**Files:**
- Create: `live_react_examples/lib/live_react_examples_web/live/stream_demo_live.ex`
- Create: `live_react_examples/assets/react-components/stream-demo.jsx`
- Modify: `live_react_examples/assets/react-components/index.js`
- Modify: `live_react_examples/lib/live_react_examples_web/router.ex`

**Interfaces:**
- Consumes: `<.react streams={@messages} .../>` (the completed feature from Tasks 1-11).
- Produces: a `/stream-demo` route for manual browser verification. Nothing else depends on this task; it exists purely to drive the feature end-to-end with `mix phx.server` per this repo's `/verify` conventions.

- [ ] **Step 1: Check the router for the existing route pattern**

Run: `grep -n "live \"/" live_react_examples/lib/live_react_examples_web/router.ex`

- [ ] **Step 2: Add the LiveView**

```elixir
defmodule LiveReactExamplesWeb.StreamDemoLive do
  use LiveReactExamplesWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:next_id, 1)
      |> stream(:messages, [%{id: 0, text: "Welcome!"}])

    {:ok, socket}
  end

  def handle_event("add", _params, socket) do
    id = socket.assigns.next_id
    socket = socket |> assign(:next_id, id + 1) |> stream_insert(:messages, %{id: id, text: "Message #{id}"})
    {:noreply, socket}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    {:noreply, stream_delete(socket, :messages, %{id: String.to_integer(id)})}
  end

  def render(assigns) do
    ~H"""
    <.react name="StreamDemo" messages={@streams.messages} socket={@socket} />
    """
  end
end
```

- [ ] **Step 3: Add the React component**

```jsx
// live_react_examples/assets/react-components/stream-demo.jsx
export default function StreamDemo({ messages, pushEvent }) {
  return (
    <div>
      <button onClick={() => pushEvent("add", {})}>Add message</button>
      <ul>
        {messages.map((message) => (
          <li key={message.__dom_id}>
            {message.text}
            <button onClick={() => pushEvent("delete", { id: message.id })}>Delete</button>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

- [ ] **Step 4: Register the component**

In `live_react_examples/assets/react-components/index.js`, add:

```js
export { default as StreamDemo } from "./stream-demo.jsx";
```

- [ ] **Step 5: Add the route**

In `live_react_examples/lib/live_react_examples_web/router.ex`, alongside the other `live "/..."` entries:

```elixir
live "/stream-demo", StreamDemoLive
```

- [ ] **Step 6: Build assets and boot the server**

Run (from `live_react_examples/`): `mix setup && mix phx.server`
Expected: server boots without errors.

- [ ] **Step 7: Manually verify in the browser**

Visit `http://localhost:4000/stream-demo`. Click "Add message" several times and confirm new list items appear without a full-page/full-list re-render (check via React DevTools "Highlight updates" that only the new row flashes, not the whole list). Click "Delete" on a middle item and confirm only that row disappears.

- [ ] **Step 8: Commit**

```bash
git add live_react_examples/lib/live_react_examples_web/live/stream_demo_live.ex \
        live_react_examples/assets/react-components/stream-demo.jsx \
        live_react_examples/assets/react-components/index.js \
        live_react_examples/lib/live_react_examples_web/router.ex
git commit -m "docs: add stream demo LiveView for manual verification"
```

---

### Task 14: `Phoenix.HTML.Form` Encoder implementation

**Added post-hoc:** the original design spec (`docs/superpowers/specs/2026-07-13-props-diff-and-streams-design.md`, §2) called for a `Phoenix.HTML.Form` implementation of `LiveReact.Encoder`, matching `LiveVue.Encoder`'s (Ecto-changeset-aware, conditional on `Code.ensure_loaded?(Ecto)`), but Task 3 silently narrowed scope to just `AsyncResult`/`UploadConfig`/`UploadEntry`. Caught by the final whole-branch review. This task closes that gap.

**Files:**
- Modify: `lib/live_react/encoder.ex` (append only — do not touch Tasks 2/3's existing content)
- Modify: `mix.exs` (add `{:ecto, "~> 3.0", optional: true}`, `{:phoenix_ecto, "~> 4.0", optional: true}`)
- Test: `test/live_react_encoder_form_test.exs`

**Interfaces:**
- Consumes: `LiveReact.Encoder.encode/2` (Task 2).
- Produces: `LiveReact.Encoder` implementation for `Phoenix.HTML.Form`. No new public functions.

- [ ] **Step 1: Add the optional deps**

In `mix.exs`, add to `defp deps do` (both `optional: true`, no `only:` restriction so they're available in `:test` env for this task's own tests):

```elixir
{:ecto, "~> 3.0", optional: true},
{:phoenix_ecto, "~> 4.0", optional: true},
```

Run: `mix deps.get`

- [ ] **Step 2: Write the failing tests**

```elixir
defmodule LiveReact.EncoderFormTest do
  use ExUnit.Case

  import Ecto.Changeset
  import Phoenix.Component, only: [to_form: 2]

  alias LiveReact.Encoder
  alias Phoenix.HTML.FormData

  defp encode_form(source, attrs) do
    module = source.__struct__
    changeset = module.changeset(source, attrs)
    form = FormData.to_form(changeset, as: module.__schema__(:source))
    Encoder.encode(form)
  end

  defmodule Simple do
    @moduledoc false
    use Ecto.Schema

    import Ecto.Changeset

    @derive {Encoder, except: [:secret]}
    embedded_schema do
      field(:name, :string)
      field(:secret, :string)
      field(:age, :integer)
      field(:active, :boolean)
      field(:tags, {:array, :string})
      field(:score, :float)
    end

    def changeset(simple, attrs) do
      simple
      |> cast(attrs, [:name, :secret, :age, :active, :tags, :score])
      |> validate_required([:name])
      |> validate_number(:age, greater_than: 0)
      |> validate_number(:score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    end
  end

  describe "Phoenix.HTML.Form encoding — Ecto changeset backed" do
    test "encodes form with simple values" do
      simple = %Simple{}
      attrs = %{name: "John", secret: "hidden_value", age: 30, active: true, tags: ["elixir", "phoenix"], score: 95.5}
      encoded = encode_form(simple, attrs)

      assert encoded == %{
               name: "simple",
               values: %{
                 id: nil,
                 name: "John",
                 age: 30,
                 active: true,
                 tags: ["elixir", "phoenix"],
                 score: 95.5
               },
               errors: %{},
               valid: true
             }
    end

    test "encodes form with validation errors" do
      simple = %Simple{}
      attrs = %{name: nil, age: -5, score: 150}
      encoded = encode_form(simple, attrs)

      assert encoded.name == "simple"
      assert encoded.valid == false

      assert encoded.values == %{
               id: nil,
               name: nil,
               age: -5,
               active: nil,
               tags: nil,
               score: 150
             }

      assert encoded.errors == %{
               name: ["can't be blank"],
               age: ["must be greater than 0"],
               score: ["must be less than or equal to 100"]
             }
    end
  end

  describe "Phoenix.HTML.Form encoding — plain map backed (no Ecto)" do
    test "encodes form backed by simple map data" do
      form_data = %{
        "name" => "John Doe",
        "email" => "john@example.com",
        "role" => "developer",
        "bio" => "Software engineer with 5 years experience",
        "notifications" => true
      }

      form = to_form(form_data, as: :user)
      encoded = Encoder.encode(form)

      assert encoded == %{
               name: "user",
               values: %{
                 "name" => "John Doe",
                 "email" => "john@example.com",
                 "role" => "developer",
                 "bio" => "Software engineer with 5 years experience",
                 "notifications" => true
               },
               errors: %{},
               valid: true
             }
    end

    test "encodes form with empty map data" do
      form_data = %{
        "name" => "",
        "email" => "",
        "role" => "",
        "bio" => "",
        "notifications" => false
      }

      form = to_form(form_data, as: :profile)
      encoded = Encoder.encode(form)

      assert encoded == %{
               name: "profile",
               values: %{
                 "name" => "",
                 "email" => "",
                 "role" => "",
                 "bio" => "",
                 "notifications" => false
               },
               errors: %{},
               valid: true
             }
    end
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `mix test test/live_react_encoder_form_test.exs`
Expected: FAIL — `Protocol.UndefinedError` for `Phoenix.HTML.Form`.

- [ ] **Step 4: Append the Form encoder implementation**

Append to `lib/live_react/encoder.ex` (after the LiveView struct impls from Task 3):

```elixir
defimpl LiveReact.Encoder, for: Phoenix.HTML.Form do
  def encode(%Phoenix.HTML.Form{} = form, opts) do
    LiveReact.Encoder.encode(
      %{
        name: form.name,
        values: encode_form_values(form, opts),
        errors: encode_form_errors(form) || %{},
        valid: get_form_validity(form)
      },
      opts
    )
  end

  defp get_form_validity(%{source: %{valid?: valid}}), do: valid
  defp get_form_validity(_), do: true

  if Code.ensure_loaded?(Ecto) do
    @relations [:embed, :assoc]

    defp collect_changeset_values(%Ecto.Changeset{} = source, opts) do
      data = Map.new(source.types, fn {field, type} -> {field, get_field_value(source, field, type, opts)} end)
      result = if is_struct(source.data), do: Map.merge(source.data, data), else: data
      Map.delete(result, :__meta__)
    end

    defp get_field_value(source, field, {tag, %{cardinality: :one}}, opts) when tag in @relations do
      case Map.fetch(source.changes, field) do
        {:ok, nil} ->
          nil

        {:ok, %Ecto.Changeset{} = changeset} ->
          collect_changeset_values(changeset, opts)

        :error ->
          case Map.fetch!(source.data, field) do
            %Ecto.Association.NotLoaded{} = not_loaded ->
              if opts[:nilify_not_loaded], do: nil, else: not_loaded

            %{__meta__: _} = value ->
              Map.delete(value, :__meta__)

            value ->
              value
          end
      end
    end

    defp get_field_value(source, field, {tag, %{cardinality: :many}}, opts) when tag in @relations do
      case Map.fetch(source.changes, field) do
        {:ok, changesets} ->
          changesets
          |> Enum.filter(&(&1.params != nil))
          |> Enum.map(&collect_changeset_values(&1, opts))

        :error ->
          case Map.fetch!(source.data, field) do
            %Ecto.Association.NotLoaded{} = not_loaded ->
              if opts[:nilify_not_loaded], do: nil, else: not_loaded

            [%{__meta__: _} | _] = value ->
              Enum.map(value, &Map.delete(&1, :__meta__))

            value ->
              value
          end
      end
    end

    defp get_field_value(source, field, _type, _opts) do
      Phoenix.HTML.FormData.Ecto.Changeset.input_value(source, %{params: source.params}, field)
    end

    def encode_form_values(%{impl: Phoenix.HTML.FormData.Ecto.Changeset, source: source}, opts) do
      source |> collect_changeset_values(opts) |> LiveReact.Encoder.encode(opts)
    end
  end

  def encode_form_values(form, opts) do
    base_values =
      form.hidden
      |> Map.new()
      |> Map.merge(form.data)
      |> Map.merge(Map.new(form.params))

    LiveReact.Encoder.encode(base_values, opts)
  end

  if Code.ensure_loaded?(Ecto) do
    defp collect_changeset_errors(%Ecto.Changeset{} = changeset) do
      errors = translate_errors(changeset.errors)

      Enum.reduce(changeset.changes, errors, fn {field, value}, acc ->
        case Map.get(changeset.types, field) do
          {tag, %{cardinality: :one}} when tag in @relations ->
            embed_errors = collect_changeset_errors(value)
            if embed_errors == %{}, do: acc, else: Map.put(acc, field, embed_errors)

          {tag, %{cardinality: :many}} when tag in @relations ->
            list_errors =
              value
              |> Enum.filter(&(&1.params != nil))
              |> Enum.map(fn embed_changeset ->
                embed_errors = collect_changeset_errors(embed_changeset)
                if embed_errors == %{}, do: nil, else: embed_errors
              end)

            if Enum.all?(list_errors, &is_nil/1), do: acc, else: Map.put(acc, field, list_errors)

          _ ->
            acc
        end
      end)
    end

    def encode_form_errors(%{impl: Phoenix.HTML.FormData.Ecto.Changeset} = form) do
      collect_changeset_errors(form.source)
    end
  end

  def encode_form_errors(form) do
    translate_errors(form.errors)
  end

  defp translate_errors(errors) do
    Map.new(errors, fn {field, error} -> {field, error |> List.wrap() |> Enum.map(&translate_error/1)} end)
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(
        acc,
        "%{#{key}}",
        value
        |> List.wrap()
        |> Enum.map_join(", ", fn
          v when is_binary(v) or is_atom(v) or is_number(v) -> to_string(v)
          v -> inspect(v)
        end)
      )
    end)
  end
end
```

Note: this port intentionally drops `LiveVue.Encoder`'s optional Gettext-backend error translation (`Application.get_env(:live_vue, :gettext_backend, ...)`) — live_react has no equivalent existing Gettext integration point in this codebase, so it's out of scope here; `translate_error/1`'s plain string-interpolation fallback (the same one live_vue itself falls back to when no Gettext backend is configured) is sufficient for parity with what most `LiveReact` users need.

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/live_react_encoder_form_test.exs`
Expected: PASS.

- [ ] **Step 6: Run the full suite for regressions**

Run: `mix test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/live_react/encoder.ex mix.exs mix.lock test/live_react_encoder_form_test.exs
git commit -m "feat: encode Phoenix.HTML.Form via LiveReact.Encoder"
```
