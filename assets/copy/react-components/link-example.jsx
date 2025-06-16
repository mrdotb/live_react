import React from "react";
import { Link } from "live_react";

export function LinkExample({}) {
  return (
    <div className="space-y-4 p-4">
      <h2 className="text-xl font-bold">Link Component Examples</h2>
      
      <div className="space-y-2">
        <p>
          <Link href="/external" className="text-blue-600 hover:underline">
            External Link (full page reload)
          </Link>
        </p>
        
        <p>
          <Link patch="/same-liveview" className="text-green-600 hover:underline">
            Patch Link (same LiveView, calls handle_params)
          </Link>
        </p>
        
        <p>
          <Link navigate="/other-liveview" className="text-purple-600 hover:underline">
            Navigate Link (different LiveView, same session)
          </Link>
        </p>
        
        <p>
          <Link 
            navigate="/replace-history" 
            replace={true} 
            className="text-red-600 hover:underline"
          >
            Replace History (navigate with replace)
          </Link>
        </p>
      </div>
    </div>
  );
} 