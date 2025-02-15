import React, { createContext, useContext } from "react";

export const LiveReactContext = createContext(null);

export function LiveReactProvider({ children, ...props }) {
  return (
    <LiveReactContext.Provider value={props}>
      {children}
    </LiveReactContext.Provider>
  );
}

export function useLiveReact() {
  return useContext(LiveReactContext);
}
