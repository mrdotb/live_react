import React from "react";
import ReactDOM from "react-dom/client";
import { getComponentTree } from "./utils";

function getAttributeJson(el, attributeName) {
  const data = el.getAttribute(attributeName);
  return data ? JSON.parse(data) : {};
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
    ...getAttributeJson(hook.el, "data-props"),
    pushEvent: hook.pushEvent.bind(hook),
    pushEventTo: hook.pushEventTo.bind(hook),
    handleEvent: hook.handleEvent.bind(hook),
    removeHandleEvent: hook.removeHandleEvent.bind(hook),
    upload: hook.upload.bind(hook),
    uploadTo: hook.uploadTo.bind(hook),
  };
}

export function getHooks(components) {
  const ReactHook = {
    _render() {
      const tree = getComponentTree(
        this._Component,
        getProps(this),
        getChildren(this),
      );
      this._root.render(tree);
    },
    mounted() {
      const componentName = this.el.getAttribute("data-name");
      if (!componentName) {
        throw new Error("Component name must be provided");
      }

      this._Component = components[componentName];

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
        this._render();
      }
    },
    updated() {
      if (this._root) {
        this._render();
      }
    },
    destroyed() {
      if (this._root) {
        window.addEventListener(
          "phx:page-loading-stop",
          () => this._root.unmount(),
          { once: true },
        );
      }
    },
  };

  return { ReactHook };
}
