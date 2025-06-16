import React from "react";

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

export interface LinkProps extends React.AnchorHTMLAttributes<HTMLAnchorElement> {
  /** Uses traditional browser navigation to the new location. This means the whole page is reloaded. */
  href?: string | null;
  /** Patches the current LiveView. The handle_params callback will be invoked with minimum content sent over the wire. */
  patch?: string | null;
  /** Navigates to a LiveView. Only works between LiveViews in the same live_session. */
  navigate?: string | null;
  /** When using patch or navigate, should the browser's history be replaced with pushState? */
  replace?: boolean;
  children?: React.ReactNode;
}

export function useLiveReact(): LiveProps;
export function Link(props: LinkProps): React.ReactElement;
