function unescapePathComponent(path) {
  return path.replace(/~1/g, "/").replace(/~0/g, "~");
}

function resolvePathComponent(component, arrayObj) {
  if (!component.startsWith("$$")) {
    return component;
  }

  const targetId = component.substring(2);
  const index = arrayObj.findIndex(
    (item) => item && typeof item === "object" && item.__dom_id == targetId,
  );

  if (index === -1) {
    console.warn(
      `JSON Patch: Item with __dom_id "${targetId}" not found in array, skipping operation`,
    );
    return null;
  }

  return index.toString();
}

function readPathSegment(path, start, end) {
  const segment = path.slice(start, end);
  return segment.indexOf("~") === -1 ? segment : unescapePathComponent(segment);
}

function resolveArrayIndex(key, arrayObj, allowAppend) {
  if (key.startsWith("$$")) {
    const resolved = resolvePathComponent(key, arrayObj);
    return resolved === null ? null : parseInt(resolved, 10);
  }

  if (key === "-") return allowAppend ? arrayObj.length : arrayObj.length - 1;
  return parseInt(key, 10);
}

export function getValueByPointer(document, pointer) {
  if (pointer === "") return document;

  const keys = pointer.split("/").slice(1);
  let obj = document;

  for (const key of keys) {
    let resolvedKey =
      key.indexOf("~") !== -1 ? unescapePathComponent(key) : key;

    if (Array.isArray(obj)) {
      if (resolvedKey.startsWith("$$")) {
        const resolved = resolvePathComponent(resolvedKey, obj);
        if (resolved === null) return undefined;
        resolvedKey = resolved;
      }
      obj =
        obj[resolvedKey === "-" ? obj.length - 1 : parseInt(resolvedKey, 10)];
    } else {
      obj = obj[resolvedKey];
    }
  }

  return obj;
}

/**
 * Apply a single patch operation on a JSON document in-place.
 */
export function applyOperation(document, operation) {
  return applyPatchOperation(
    document,
    operation.op,
    operation.path,
    operation.value,
  );
}

function applyPatchOperation(document, op, path, value) {
  if (path === "") {
    switch (op) {
      case "add":
      case "replace":
        return value;
      case "test":
        return document;
      case "remove":
        return null;
    }
  }

  let obj = document;
  let segmentStart = 1;

  while (true) {
    const segmentEnd = path.indexOf("/", segmentStart);
    if (segmentEnd === -1) break;

    const key = readPathSegment(path, segmentStart, segmentEnd);

    if (Array.isArray(obj)) {
      const index = resolveArrayIndex(key, obj, false);
      if (index === null) return document;
      obj = obj[index];
    } else {
      obj = obj[key];
    }

    segmentStart = segmentEnd + 1;
  }

  const unescapedKey = readPathSegment(path, segmentStart, path.length);

  if (Array.isArray(obj)) {
    const resolvedIndex = resolveArrayIndex(unescapedKey, obj, true);
    if (resolvedIndex === null) return document;
    const index = resolvedIndex;

    switch (op) {
      case "add":
        obj.splice(index, 0, value);
        break;
      case "remove":
        obj.splice(index, 1);
        break;
      case "replace":
        obj[index] = value;
        break;
      case "upsert":
        if (value && typeof value === "object" && "__dom_id" in value) {
          const existingIndex = obj.findIndex(
            (item) =>
              item &&
              typeof item === "object" &&
              item.__dom_id === value.__dom_id,
          );

          if (existingIndex !== -1) {
            obj[existingIndex] = value;
          } else {
            obj.splice(index, 0, value);
          }
        } else {
          obj.splice(index, 0, value);
        }
        break;
      case "test":
        break;
      case "limit":
        if (value >= 0) {
          if (value < obj.length) obj.splice(value);
        } else {
          const keepCount = Math.abs(value);
          if (keepCount < obj.length) obj.splice(0, obj.length - keepCount);
        }
        break;
    }
  } else {
    switch (op) {
      case "add":
      case "replace":
        obj[unescapedKey] = value;
        break;
      case "remove":
        delete obj[unescapedKey];
        break;
      case "test":
        break;
      case "limit":
        const targetArray = obj[unescapedKey];
        if (Array.isArray(targetArray)) {
          if (value >= 0) {
            if (value < targetArray.length) targetArray.splice(value);
          } else {
            const keepCount = Math.abs(value);
            if (keepCount < targetArray.length)
              targetArray.splice(0, targetArray.length - keepCount);
          }
        }
        break;
    }
  }

  return document;
}

function cloneShallow(value) {
  if (Array.isArray(value)) return value.slice();
  if (value && typeof value === "object") return { ...value };
  return value;
}

/**
 * Clones every container from `document` down to (but not including) the
 * value that `path`'s final segment addresses, the first time this patch
 * batch touches each one — so the eventual write, wherever in
 * applyPatchOperation's own traversal it lands, always mutates a
 * this-batch-fresh object/array instead of aliasing a value some other
 * live reference (a prior render's props, a memoized child's captured
 * item) still points to.
 *
 * Segment 1 is always a clone candidate, even for single-segment paths
 * like `/users` — that's what `applyPatchOperation`'s top-level splice/
 * assign (e.g. the `limit` operation) mutates directly. Segments 2..N-1
 * extend the same guarantee to nested paths like `/items/1/name`, where
 * both `document.items` (the array) and `document.items[1]` (the item)
 * need fresh references before the write two levels down.
 *
 * The final segment itself is deliberately left uncloned: cloning the
 * value living there would corrupt append-style inserts (a path ending in
 * `/-`, since there's no existing value at the append index yet), and
 * every other operation either overwrites that slot outright or mutates
 * its already-fresh parent — neither needs the old value pre-cloned.
 */
function ensureWritablePath(document, path, touchedPaths) {
  let obj = document;
  let segmentStart = 1;
  let prefix = "";

  while (true) {
    const segmentEnd = path.indexOf("/", segmentStart);
    if (segmentEnd === -1) break;

    const key = readPathSegment(path, segmentStart, segmentEnd);
    let resolvedKey = key;

    if (Array.isArray(obj)) {
      const index = resolveArrayIndex(key, obj, false);
      if (index === null) return;
      resolvedKey = index;
    }

    prefix += "/" + resolvedKey;

    if (!touchedPaths.has(prefix)) {
      touchedPaths.add(prefix);
      obj[resolvedKey] = cloneShallow(obj[resolvedKey]);
    }

    obj = obj[resolvedKey];
    segmentStart = segmentEnd + 1;
  }

  if (prefix === "") {
    const key = readPathSegment(path, segmentStart, path.length);
    const singleSegmentPrefix = "/" + key;

    if (!touchedPaths.has(singleSegmentPrefix)) {
      touchedPaths.add(singleSegmentPrefix);
      obj[key] = cloneShallow(obj[key]);
    }
  }
}

export function applyPatch(document, patch) {
  let result = document;
  const touchedPaths = new Set();

  for (const operation of patch) {
    if (operation.path === "") {
      result = applyOperation(result, operation);
      continue;
    }

    ensureWritablePath(result, operation.path, touchedPaths);
    applyOperation(result, operation);
  }

  return result;
}
