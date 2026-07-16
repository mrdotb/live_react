import { vi } from "vitest";

let mockIdCounter = 0;

export const createMockLiveViewHook = (elementAttributes = {}) => {
  const id = elementAttributes.id || `mock-${++mockIdCounter}`;
  const attributes = { ...elementAttributes };

  const mockElement = {
    id,
    getAttribute: vi.fn((name) =>
      name in attributes ? attributes[name] : null,
    ),
    setAttribute: vi.fn((name, value) => {
      attributes[name] = value;
    }),
    hasAttribute: vi.fn((name) => name in attributes),
    hasChildNodes: vi.fn(() => false),
  };

  return {
    el: mockElement,
    pushEvent: vi.fn(),
    pushEventTo: vi.fn(),
    handleEvent: vi.fn(),
    removeHandleEvent: vi.fn(),
    upload: vi.fn(),
    uploadTo: vi.fn(),
  };
};
