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
