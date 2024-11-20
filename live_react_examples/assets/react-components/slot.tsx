import React from "react";

export function Slot({ children }: { children: React.ReactNode }) {
  return <div className="flex">{children}</div>;
}
