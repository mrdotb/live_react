// polyfill recommended by Vite https://vitejs.dev/config/build-options#build-modulepreload
import "vite/modulepreload-polyfill";

import { Context } from "./context";
import { Counter } from "./counter";
import { DelaySlider } from "./delay-slider";
import { FlashSonner } from "./flash-sonner";
import { GithubCode } from "./github-code";
import { Lazy } from "./lazy";
import { LogList } from "./log-list";
import { SSR } from "./ssr";
import { Simple } from "./simple";
import { SimpleProps } from "./simple-props";
import { Slot } from "./slot";
import { Typescript } from "./typescript";

export default {
  Context,
  Counter,
  DelaySlider,
  FlashSonner,
  GithubCode,
  Lazy,
  LogList,
  SSR,
  Simple,
  SimpleProps,
  Slot,
  Typescript,
};
