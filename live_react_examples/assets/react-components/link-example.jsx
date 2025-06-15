import React from "react";
import { Link } from "live_react";

export function LinkExample({ currentPath = "/" }) {
  return (
    <div className="max-w-4xl mx-auto p-6 space-y-8">
      <div className="text-center">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">
          LiveReact Link Component Examples
        </h1>
        <p className="text-gray-600">
          Current path: <code className="bg-gray-100 px-2 py-1 rounded">{currentPath}</code>
        </p>
      </div>

      <div className="grid md:grid-cols-2 gap-8">
        {/* Traditional Links */}
        <div className="bg-white p-6 rounded-lg shadow-md border">
          <h2 className="text-xl font-semibold text-gray-800 mb-4">
            Traditional Navigation (href)
          </h2>
          <p className="text-gray-600 mb-4">
            These links cause full page reloads, just like regular HTML links.
          </p>
          <div className="space-y-3">
            <div>
              <Link 
                href="/simple" 
                className="inline-block bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded transition-colors"
              >
                Go to Simple Page (href)
              </Link>
            </div>
            <div>
              <Link 
                href="/typescript" 
                className="inline-block bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded transition-colors"
              >
                Go to TypeScript Page (href)
              </Link>
            </div>
          </div>
        </div>

        {/* LiveView Patch Links */}
        <div className="bg-white p-6 rounded-lg shadow-md border">
          <h2 className="text-xl font-semibold text-gray-800 mb-4">
            LiveView Patch (patch)
          </h2>
          <p className="text-gray-600 mb-4">
            Patch stays in the same LiveView process, calls handle_params.
          </p>
          <div className="space-y-3">
            <div>
              <Link 
                patch="/link-demo?tab=basics" 
                className="inline-block bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded transition-colors"
              >
                Patch to Basics Tab
              </Link>
            </div>
            <div>
              <Link 
                patch="/link-demo?tab=advanced" 
                className="inline-block bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded transition-colors"
              >
                Patch to Advanced Tab
              </Link>
            </div>
          </div>
        </div>

        {/* LiveView Navigate Links */}
        <div className="bg-white p-6 rounded-lg shadow-md border">
          <h2 className="text-xl font-semibold text-gray-800 mb-4">
            LiveView Navigate (navigate)
          </h2>
          <p className="text-gray-600 mb-4">
            Navigate to different LiveViews within the same live_session.
          </p>
          <div className="space-y-3">
            <div>
              <Link 
                navigate="/live-counter" 
                className="inline-block bg-purple-500 hover:bg-purple-600 text-white px-4 py-2 rounded transition-colors"
              >
                Navigate to Counter
              </Link>
            </div>
            <div>
              <Link 
                navigate="/context" 
                className="inline-block bg-purple-500 hover:bg-purple-600 text-white px-4 py-2 rounded transition-colors"
              >
                Navigate to Context
              </Link>
            </div>
            <div>
              <Link 
                navigate="/ssr" 
                className="inline-block bg-purple-500 hover:bg-purple-600 text-white px-4 py-2 rounded transition-colors"
              >
                Navigate to SSR
              </Link>
            </div>
          </div>
        </div>

        {/* History Replace */}
        <div className="bg-white p-6 rounded-lg shadow-md border">
          <h2 className="text-xl font-semibold text-gray-800 mb-4">
            Replace History (replace)
          </h2>
          <p className="text-gray-600 mb-4">
            Replace browser history instead of adding new entries.
          </p>
          <div className="space-y-3">
            <div>
              <Link 
                navigate="/flash-sonner" 
                replace={true}
                className="inline-block bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded transition-colors"
              >
                Replace to Flash Sonner
              </Link>
            </div>
            <div>
              <Link 
                patch="/link-demo?replaced=true" 
                replace={true}
                className="inline-block bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded transition-colors"
              >
                Replace with Patch
              </Link>
            </div>
          </div>
        </div>
      </div>

      {/* Test Area */}
      <div className="bg-gray-50 p-6 rounded-lg">
        <h2 className="text-xl font-semibold text-gray-800 mb-4">
          Test Area
        </h2>
        <p className="text-gray-600 mb-4">
          Use your browser's back/forward buttons to test navigation behavior.
          Notice the difference between href (full reload), patch (same process), 
          and navigate (new process) links.
        </p>
        <div className="flex flex-wrap gap-2">
          <Link 
            href="/" 
            className="bg-gray-200 hover:bg-gray-300 px-3 py-1 rounded text-sm transition-colors"
          >
            Home (href)
          </Link>
          <Link 
            navigate="/link-demo" 
            className="bg-gray-200 hover:bg-gray-300 px-3 py-1 rounded text-sm transition-colors"
          >
            Link Demo (navigate)
          </Link>
          <Link 
            navigate="/link-usage" 
            className="bg-gray-200 hover:bg-gray-300 px-3 py-1 rounded text-sm transition-colors"
          >
            Link Usage (navigate)
          </Link>
          <Link 
            patch="/link-demo?reset=true" 
            className="bg-gray-200 hover:bg-gray-300 px-3 py-1 rounded text-sm transition-colors"
          >
            Reset (patch)
          </Link>
        </div>
      </div>
    </div>
  );
} 