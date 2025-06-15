import React, { useMemo } from "react";

/**
 * Phoenix LiveView Link component for React
 * 
 * Handles different types of navigation in Phoenix LiveView:
 * - href: Traditional browser navigation (full page reload)
 * - patch: Patches the current LiveView (calls handle_params)
 * - navigate: Navigates to a different LiveView within the same live_session
 * - replace: Whether to replace or push browser history
 */
export function Link({ 
  href = null, 
  patch = null, 
  navigate = null, 
  replace = false, 
  children, 
  ...attrs 
}) {
  const linkAttrs = useMemo(() => {
    if (!patch && !navigate) {
      return {
        href: href || "#",
      };
    }

    return {
      href: (navigate ? navigate : patch) || "#",
      "data-phx-link": navigate ? "redirect" : "patch",
      "data-phx-link-state": replace ? "replace" : "push",
    };
  }, [href, patch, navigate, replace]);

  return (
    <a {...attrs} {...linkAttrs}>
      {children}
    </a>
  );
} 