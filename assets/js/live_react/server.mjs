import React from "react";
import { renderToString } from "react-dom/server";
import { getComponentTree } from "./utils";

function getChildren(slots) {
  if (!slots?.default) {
    return [];
  }

  return [
    React.createElement("div", {
      dangerouslySetInnerHTML: { __html: slots.default.trim() },
    }),
  ];
}

export function getRender(components) {
  return function render(name, props, slots) {
    const Component = components[name];
    if (!Component) {
      throw new Error(`Component "${name}" not found`);
    }
    const children = getChildren(slots);
    const tree = getComponentTree(Component, props, children);

    // https://react.dev/reference/react-dom/server/renderToString
    return renderToString(tree);
  };
}
