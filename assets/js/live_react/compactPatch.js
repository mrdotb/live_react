export const decodeCompactPatch = (payload) => {
  if (!payload) return [];

  const operations = [];
  let offset = 0;

  while (offset < payload.length) {
    const code = payload[offset++];

    if (code === "n") {
      offset = skipDigits(payload, offset);
      continue;
    }

    const op = opFromCode(code);
    const pathLength = readLength(payload, offset);
    offset = pathLength.offset;

    const path = payload.slice(offset, offset + pathLength.value);
    offset += pathLength.value;

    if (op === "remove") {
      operations.push({ op, path });
      continue;
    }

    const tag = payload[offset++];

    if (tag === "z") {
      operations.push({ op, path, value: null });
      continue;
    }

    if (tag === "b") {
      operations.push({ op, path, value: payload[offset++] === "1" });
      continue;
    }

    const valueLength = readLength(payload, offset);
    offset = valueLength.offset;

    const rawValue = payload.slice(offset, offset + valueLength.value);
    offset += valueLength.value;

    if (tag === "n") {
      operations.push({ op, path, value: Number(rawValue) });
    } else if (tag === "s") {
      operations.push({ op, path, value: rawValue });
    } else if (tag === "J") {
      operations.push({ op, path, value: decodeCompactJson(rawValue) });
    } else {
      throw new Error(`Unknown LiveReact patch value tag: ${tag}`);
    }
  }

  return operations;
};

const opFromCode = (code) => {
  switch (code) {
    case "a":
      return "add";
    case "d":
      return "remove";
    case "r":
      return "replace";
    case "u":
      return "upsert";
    case "l":
      return "limit";
    default:
      throw new Error(`Unknown LiveReact patch operation code: ${code}`);
  }
};

const readLength = (payload, offset) => {
  let value = 0;
  let hasDigits = false;

  while (offset < payload.length) {
    const code = payload.charCodeAt(offset);
    if (code < 48 || code > 57) break;
    value = value * 10 + code - 48;
    offset++;
    hasDigits = true;
  }

  if (!hasDigits || payload[offset] !== ":") throw new Error("Invalid LiveReact patch length prefix");
  return { value, offset: offset + 1 };
};

const skipDigits = (payload, offset) => {
  while (offset < payload.length) {
    const code = payload.charCodeAt(offset);
    if (code < 48 || code > 57) break;
    offset++;
  }

  return offset;
};

export const decodeCompactJson = (value) => {
  return JSON.parse(
    value.replace(/~~|~\^|\^/g, (match) => {
      if (match === "~~") return "~";
      if (match === "~^") return "^";
      return '"';
    }),
  );
};
