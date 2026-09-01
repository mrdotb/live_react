# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v2.0.0](https://github.com/mrdotb/live_react/compare/v1.1.0...v2.0.0) (2026-09-01)

### Breaking Changes:

* `data-props` is now encoded via the new `LiveReact.Encoder` protocol instead of `Jason.Encoder`. Struct props must now `@derive LiveReact.Encoder` (or implement it explicitly) — plain maps are unaffected. See [Upgrading to 2.0](guides/upgrading-to-2.0.md) for migration examples.

### Features:

* Props are now diffed and sent incrementally over `data-props-diff` instead of being fully re-sent on every update (`config :live_react, enable_props_diff: true` by default; opt out globally with `false` or per-component with `diff={false}`).

* Added support for `Phoenix.LiveView.stream/4` assigns: a stream passed as a prop is now automatically diffed and delivered over `data-streams-diff`, arriving on the client as an array whose items carry their `__dom_id`.

* `LiveReact.Encoder` ships implementations for the structs most likely to be passed as props: `Phoenix.HTML.Form` (including Ecto changeset values and errors), `Phoenix.LiveView.AsyncResult`, `Phoenix.LiveView.UploadConfig`, `Phoenix.LiveView.UploadEntry`, and `Date`, `Time`, `NaiveDateTime` and `DateTime`.

### Bug Fixes:

* Props diffing no longer requires the call site to pass `socket`. A render was previously treated as dead whenever `socket` was absent, which forced the full-props branch on every update: `data-props` was resent carrying only the *changed* keys, while `data-props-diff` was never marked as changed. A client in diff mode therefore read a diff attribute that never moved and silently stopped updating. `dead` is now only derived on the initial render, where it is both knowable and the only place it is used.

* Cleared the compiler warnings raised by Elixir 1.20.

### Documentation:

* Added the [Props Diffing and Streams](guides/props-diffing.md) and [Upgrading to 2.0](guides/upgrading-to-2.0.md) guides, and documented the reserved assigns of `LiveReact.react/1`.

* The example application moved to its own repository, [mrdotb/live_react_examples](https://github.com/mrdotb/live_react_examples).

## [v1.1.0](https://github.com/mrdotb/live_react/compare/v1.0.1...v1.1.0) (2025-06-22)

### Features:

* Add React Link component for Phoenix LiveView navigation by Gaoge Zhang

## [v1.0.1](https://github.com/mrdotb/live_react/compare/v1.0.1...v1.0.0) (2025-04-20)

### Bug Fixes:

* add missing useLiveReact type


## [v1.0.0](https://github.com/mrdotb/live_react/compare/v1.0.0...v1.0.0-rc.4) (2025-03-10)

### Breaking Changes:

* vitejs: switch from Mix Esbuild to Vite.js

### Features:

* add tests based on the one from live_vue
* add SSR support
* support inner_block slot
* context provider for live_react
* add typescript support


## [v1.0.0-rc.4](https://github.com/mrdotb/live_react/compare/v1.0.0-rc.3...v1.0.0-rc.4) (2025-01-22)

### Features:

* add tests based on the one from live_vue

### Bug Fixes:

* Ensure app.ts entrypoints can be used with @react-refresh

## [v1.0.0-rc.3](https://github.com/mrdotb/live_react/compare/v1.0.0-rc.2...v1.0.0-rc.3) (2024-12-08)


### Features:

* support inner_block slot

## [v1.0.0-rc.2](https://github.com/mrdotb/live_react/compare/v1.0.0-rc.1...v1.0.0-rc.2) (2024-12-01)




### Features:

* Added SSR duration logging to example app

### Bug Fixes:

* rename react folder to react-components to prevent Vite error

## [v1.0.0-rc.1](https://github.com/mrdotb/live_react/compare/v1.0.0-rc.0...v1.0.0-rc.1) (2024-10-12)




### Bug Fixes:

* missing files in mix.exs to ship the js

## [v1.0.0-rc.0](https://github.com/mrdotb/live_react/compare/v0.2.0-rc.0...v1.0.0-rc.0) (2024-10-05)
### Breaking Changes:

* vitejs: switch from Mix Esbuild to Vite.js

## [v0.2.0-rc.0](https://github.com/mrdotb/live_react/compare/v0.2.0-rc.0...v0.2.0-rc.0) (2024-09-17)

### Features

* Add SSR support

### Bug Fixes:

* ssr: remove compiler warning when using live_react without SSR

## v0.1.0 (2024-06-29)

Initial release
