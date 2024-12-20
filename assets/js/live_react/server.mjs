import React from "react";
import { renderToString } from "react-dom/server";

function Wrapper({ children }) {
  return React.createElement(React.Fragment, null, children);
}

export function getRender(components) {
  return function render(name, props, slots) {
    const Component = components[name];
    if (!Component) {
      throw new Error(`Component "${name}" not found`);
    }

    let children = [];
    if (slots?.default) {
      children.push(
        React.createElement("div", {
          dangerouslySetInnerHTML: { __html: slots.default.trim() },
        }),
      );
    }

    // The Component need to be wrapped to prevent useState useEffect error which can't be root component
    const componentInstance = React.createElement(
      Component,
      props,
      ...children,
    );
    const content = React.createElement(Wrapper, null, componentInstance);

    // https://react.dev/reference/react-dom/server/renderToString
    return renderToString(content);
  };
}
