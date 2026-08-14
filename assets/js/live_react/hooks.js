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
  hook._streams = applyPatch(
    hook._streams,
    getDiff(hook.el, "data-streams-diff"),
  );
}

function refreshProps(hook) {
  if (hook.el.getAttribute("data-use-diff") === "true") {
    hook._props = applyPatch(hook._props, getDiff(hook.el, "data-props-diff"));
  } else {
    hook._props = getBaseProps(hook.el);
  }
}

// Renders via a module-level function (rather than a `this._render()` method
// on the hook object) so it works regardless of how `mounted`/`updated`/
// `reconnected` are invoked. In production, LiveView's ViewHook merges every
// key of the hook definition (including a `_render` method) onto the same
// instance before calling any callback, so `this._render()` would resolve —
// but that merging is an internal LiveView implementation detail, not part
// of the public hook contract, so we don't rely on it here.
function render(hook) {
  const tree = getComponentTree(
    hook._Component,
    getProps(hook),
    getChildren(hook),
  );
  hook._root.render(tree);
}

export function getHooks(components) {
  const ReactHook = {
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
        const tree = getComponentTree(
          this._Component,
          getProps(this),
          getChildren(this),
        );
        this._root = ReactDOM.hydrateRoot(this.el, tree);
      } else {
        this._root = ReactDOM.createRoot(this.el);
        render(this);
      }
    },
    updated() {
      if (this._root) {
        refreshProps(this);
        refreshStreams(this);
        render(this);
      }
    },
    reconnected() {
      if (this._root) {
        // Unlike updated(), always do a full props resync from the current
        // data-props attribute rather than applying data-props-diff. On
        // reconnect the LiveView process is fresh (assigns.__changed__ ==
        // nil), so the server-computed diff is a no-op even though state may
        // have advanced while disconnected — but the full snapshot in
        // data-props is always current, so read that directly.
        this._props = getBaseProps(this.el);
        refreshStreams(this);
        render(this);
      }
    },
    destroyed() {
      const root = this._root;
      if (!root) return;

      this._root = null;
      root.unmount();
    },
  };

  return { ReactHook };
}
