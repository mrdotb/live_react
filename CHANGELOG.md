# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [Unreleased]

### Features:

* **Link Component**: Add React Link component for Phoenix LiveView navigation

  The new `Link` component provides seamless navigation within Phoenix LiveView applications, supporting all LiveView navigation patterns:
  
  - `href` - Traditional browser navigation (full page reload)
  - `patch` - Patch current LiveView (calls handle_params)
  - `navigate` - Navigate to different LiveView (same live_session)
  - `replace` - Replace browser history instead of push

  ```jsx
  import { Link } from "live_react";
  
  <Link href="/external">External Link</Link>
  <Link patch="/same?tab=new">Patch Current LV</Link>
  <Link navigate="/other">Navigate to Other LV</Link>
  <Link navigate="/path" replace={true}>Replace History</Link>
  ```

### 🔄 Upgrade Guide for Existing Projects

#### ✅ Automatic Updates (via `mix deps.update`)
These files are automatically updated when you update the `live_react` dependency:
- `assets/js/live_react/link.jsx` - New Link component
- `assets/js/live_react/index.mjs` - Updated exports
- `assets/js/live_react/index.d.mts` - New TypeScript definitions

#### 📝 Use Link in your React components

```javascript
// assets/react-components/index.js
import { Link } from "live_react";

export default {
  // ... your existing components
  Link,  // Add this line
};
```

#### 🚀 Quick Start (No Manual Updates Needed)
You can start using the Link component immediately after updating:

```elixir
# In any LiveView template
<.react name="Link" href="/some-page">Click me</.react>
<.react name="Link" patch="/current?tab=new">Patch</.react>
<.react name="Link" navigate="/other-live-view">Navigate</.react>
```

#### 📊 What's Updated in live_react_examples
If you're using the examples app as reference, these files have been updated:
- Added `/link-demo` and `/link-usage` routes
- Updated navigation in layout
- Added demo LiveViews and React components
- Updated documentation

---

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
