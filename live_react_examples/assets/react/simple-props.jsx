import React from "react";

export function SimpleProps({ user }) {
  return (
    <div>
      An example of how to pass a struct to Svelte:
      {JSON.stringify(user)}
    </div>
  );
}
