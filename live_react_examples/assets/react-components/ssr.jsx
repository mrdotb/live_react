import React from "react";

export function SSR({ text }) {
  return <div className="p-4 rounded-xl bg-card shadow">{text}</div>;
}
