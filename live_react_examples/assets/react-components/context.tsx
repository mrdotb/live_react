import React, { useState } from "react";
import { useLiveReact } from "live_react";

export function Context({ count }: { count: number }) {
  const [amount, setAmount] = useState(1);
  const { pushEvent } = useLiveReact();

  return (
    <div className="flex flex-col justify-center items-center gap-4">
      <div className="flex flex-row items-center justify-center gap-10">
        <button
          className="px-4 py-2 rounded bg-red-500 text-white cursor-pointer"
          onClick={() => pushEvent("set_count", { value: count - amount })}
        >
          -{amount}
        </button>
        <span className="text-xl">{count}</span>
        <button
          className="px-4 py-2 rounded bg-green-500 text-white cursor-pointer"
          onClick={() => pushEvent("set_count", { value: count + amount })}
        >
          +{amount}
        </button>
      </div>
      <label>
        Amount:
        <input
          onChange={(e) => setAmount(parseInt(e.target.value, 10))}
          type="number"
          className="rounded"
          value={amount}
          min="1"
        />
      </label>
    </div>
  );
}
