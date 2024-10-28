import React from "react";

export function SimpleProps({ user }) {
  return (
    <div>
      An example of how to pass a struct to React:
      {JSON.stringify(user)}
    </div>
  );
}
