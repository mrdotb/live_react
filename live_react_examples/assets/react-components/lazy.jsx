import React, { Suspense } from "react";
const LazyComponent = React.lazy(
  () => import("./components/lazy-component.jsx"),
);

export function Lazy() {
  return (
    <div>
      <h1>Hello, Vite with Code Splitting and Lazy Loading!</h1>
      <Suspense fallback={<div>Loading...</div>}>
        <LazyComponent />
      </Suspense>
    </div>
  );
}
