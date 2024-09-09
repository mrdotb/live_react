# Development

## React deduplication

Because live-react depends on react and react-dom and putting a dependency using file: in package.json does not guarantee deduplication we need to publish the package on npm.

When developing live-react locally you should use [Verdaccio](https://verdaccio.org/)

```bash
npm i -g verdaccio
verdaccio
```

In another shell

```bash
# The adduser is only needed once
npm adduser --registry http://localhost:4873/
# from project root publish the package
npm publish --registry http://localhost:4873/

cd live_react_examples/assets
npm i @mrdotb/live-react@0.x.0 --registry http://localhost:4873/
```

This is not the best solution but I could not find a better one yet.
