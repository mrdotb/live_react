# Development

## The library

```bash
git clone https://github.com/mrdotb/live_react.git
cd live_react
mix deps.get
npm install
mix test
npm test
```

## Running the examples against your working copy

The demo application lives in its own repository,
[mrdotb/live_react_examples](https://github.com/mrdotb/live_react_examples). It
depends on the published `live_react` package by default. Clone it next to this
one and set `LIVE_REACT_PATH` to point it at your local checkout instead:

```bash
git clone https://github.com/mrdotb/live_react_examples.git
cd live_react_examples

export LIVE_REACT_PATH=../live_react
mix deps.get

# The JS side resolves the library through `file:../deps/live_react`, and Mix
# does not populate deps/ for a path dependency, so link it yourself:
ln -sfn ../../live_react deps/live_react

mix setup
mix phx.server
```

Keep `LIVE_REACT_PATH` exported for every `mix` command in that shell — without
it the app falls back to the Hex release on the next `mix deps.get`, which also
replaces the symlink.

The examples include demonstrations of the Link component for LiveView
navigation at `/link-demo` and `/link-usage`, and of Phoenix streams at
`/stream-demo`.
