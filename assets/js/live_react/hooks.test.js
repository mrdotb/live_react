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
const OP_CODES = {
  add: "a",
  remove: "d",
  replace: "r",
  upsert: "u",
  limit: "l",
};

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
      if (name === "data-props-diff")
        return encodePatch([["replace", "/title", "World"]]);
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
      if (name === "data-streams-diff")
        return encodePatch([["upsert", "/users/-", { __dom_id: "u2" }]]);
      return null;
    });

    ReactHook.updated.call(hook);

    expect(lastRenderedProps().users).toEqual([
      { __dom_id: "u1" },
      { __dom_id: "u2" },
    ]);
  });

  it("reconnected() resyncs streams via diff, same as updated()", () => {
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
      if (name === "data-props") return encodeProps({ title: "Hello" });
      if (name === "data-props-diff") return null;
      if (name === "data-streams-diff")
        return encodePatch([["upsert", "/users/-", { __dom_id: "u2" }]]);
      return null;
    });

    ReactHook.reconnected.call(hook);

    expect(lastRenderedProps().users).toEqual([
      { __dom_id: "u1" },
      { __dom_id: "u2" },
    ]);
  });

  it("reconnected() does a full props resync from data-props instead of applying a diff", () => {
    // Regression test: on a real LiveView reconnect the server process is
    // fresh (assigns.__changed__ == nil), so calculate_props_diff/2 produces
    // an EMPTY diff regardless of how much server state actually changed
    // while disconnected. The full, current snapshot is sent via data-props
    // instead. reconnected() must read that fresh snapshot rather than
    // applying the (necessarily empty) data-props-diff to the stale
    // in-memory props, or the component would keep showing stale data after
    // reconnecting.
    const hook = createMockLiveViewHook({
      "data-name": "TestComponent",
      "data-props": encodeProps({ title: "Hello" }),
    });

    ReactHook.mounted.call(hook);
    expect(lastRenderedProps().title).toBe("Hello");

    hook.el.getAttribute.mockImplementation((name) => {
      if (name === "data-use-diff") return "true";
      // Fresh full snapshot reflecting server state that advanced while
      // disconnected...
      if (name === "data-props") return encodeProps({ title: "World" });
      // ...paired with the empty diff the server actually sends on
      // reconnect (init = true means calculate_props_diff/2 has nothing to
      // report).
      if (name === "data-props-diff") return encodePatch([]);
      if (name === "data-streams-diff") return null;
      return null;
    });

    ReactHook.reconnected.call(hook);

    expect(lastRenderedProps().title).toBe("World");
  });
});
