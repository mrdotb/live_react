[![Hex.pm](https://img.shields.io/hexpm/v/live_react.svg)](https://hex.pm/packages/live_react)
[![Hexdocs.pm](https://img.shields.io/badge/docs-hexdocs.pm-purple)](https://hexdocs.pm/live_react)
[![GitHub](https://img.shields.io/github/stars/mrdotb/live_react?style=social)](https://github.com/mrdotb/live_react)

# LiveReact

React inside Phoenix LiveView.

![logo](https://github.com/mrdotb/live_react/blob/main/logo.svg?raw=true)

## Features

- ⚡ **End-To-End Reactivity** with LiveView
- 🔋 **Server-Side Rendered** (SSR) React
- 🦄 **Tailwind** Support
- 💀 **Dead View** Support
- 🐌 **Lazy-loading** React Components
- 🦥 **Slot** Interoperability
- 🚀 **Amazing DX** with Vite

## Resources

- [Demo](https://live-react-examples.fly.dev/simple)
- [HexDocs](https://hexdocs.pm/live_react)
- [HexPackage](https://hex.pm/packages/live_react)
- [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view)
- [Installation](/guides/installation.md)
- [Deployment](/guides/deployment.md)
- [Development](/guides/development.md)
- [SSR](/guides/ssr.md)

## Example

Visit the [demo website](https://live-react-examples.fly.dev/simple) to see examples of what you can do with LiveReact.

You can also check out the [PhoenixAnalytics project](https://github.com/lalabuy948/PhoenixAnalytics) for a real-world example.

## Why LiveReact

Phoenix LiveView enables rich, real-time user experiences with server-rendered HTML.
It works by communicating any state changes through a websocket and updating the DOM in realtime.
You can get a really good user experience without ever needing to write any client side code.

LiveReact builds on top of Phoenix LiveView to allow for easy client side state management while still allowing for communication over the websocket.

## Installation

see [Installation](/guides/installation.md)

## Roadmap 🎯

- [ ] Pre-build SSR components for static props
- [ ] `useLiveForm` - an utility to efforlessly use Ecto changesets & server-side validation, similar to HEEX
- [ ] Add support for Phoenix streams as props

## Credits

I was inspired by the following libraries:

- [LiveVue](https://github.com/Valian/live_vue)
- [LiveSvelte](https://github.com/woutdp/live_svelte)

I had a need for a similar library for React and so I created LiveReact 👍
