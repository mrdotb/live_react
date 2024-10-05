// polyfill recommended by Vite https://vitejs.dev/config/build-options#build-modulepreload
import "vite/modulepreload-polyfill";

import { Simple } from "./simple";
import { SimpleProps } from "./simple-props";
import { Counter } from "./counter";
import { LogList } from "./log-list";
import { Typescript } from "./typescript";
import { GithubCode } from "./github-code";
import { Lazy } from "./lazy";
import { FlashSonner } from "./flash-sonner";
import { SSR } from "./ssr";

export default {
  Simple,
  SimpleProps,
  Counter,
  LogList,
  Typescript,
  GithubCode,
  Lazy,
  FlashSonner,
  SSR,
};
