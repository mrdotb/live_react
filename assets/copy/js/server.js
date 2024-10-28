// Used by the node.js worker for server-side rendering
import { getRender } from "live_react/server";
import components from "../react-components";

export const render = getRender(components);
