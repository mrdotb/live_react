import React from "react";
import { ViewHookInterface } from "phoenix_live_view";

export interface LiveProps {
  pushEvent: (
    event: string,
    payload?: Record<string, any>,
    onReply?: (reply: Record<string, any>) => void,
  ) => Promise<any> | void;
  pushEventTo: (
    phxTarget: string | HTMLElement,
    event: string,
    payload?: Record<string, any>,
    onReply?: (reply: Record<string, any>) => void,
  ) => Promise<any> | void;
  handleEvent: (
    event: string,
    callback: (payload: Record<string, any>) => void,
  ) => string;
  removeHandleEvent: (callbackRef: string) => void;
  upload: (name: string, files: FileList | File[]) => void;
  uploadTo: (target: string, name: string, files: FileList | File[]) => void;
}

export function useLiveReact(): LiveProps;

interface ReactHookType {
  _render: () => void;
  mounted: () => void;
  updated: () => void;
  destroyed: () => void;
}

/**
 * Creates React hook handlers for Phoenix LiveView
 */
export function getHooks(components: Record<string, React.ComponentType<any>>): {
  ReactHook: ReactHookType;
};
