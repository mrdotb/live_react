import React from "react";
import type { LiveProps } from "live_react";

function MyButton({ title }: { title: string }) {
  return (
    <button className="bg-indigo-500 py-2 px-3 rounded text-white cursor-pointer">
      {title}
    </button>
  );
}

export function Typescript(props: LiveProps) {
  console.log(props);

  return (
    <div className="flex flex-col space-y-4">
      <h1>Typescript</h1>
      <div>
        <MyButton title="I'm a typed button" />
      </div>
    </div>
  );
}
