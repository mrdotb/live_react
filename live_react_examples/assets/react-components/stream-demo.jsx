import { useState } from "react";

export function StreamDemo({ messages = [], pushEvent }) {
  const [draft, setDraft] = useState("");
  const [editingId, setEditingId] = useState(null);
  const [editText, setEditText] = useState("");

  const send = (e) => {
    e.preventDefault();
    pushEvent("add", { text: draft });
    setDraft("");
  };

  const startEditing = (message) => {
    setEditingId(message.id);
    setEditText(message.text);
  };

  const stopEditing = () => {
    setEditingId(null);
    setEditText("");
  };

  const saveEdit = (e) => {
    e.preventDefault();
    pushEvent("edit", { id: editingId, text: editText });
    stopEditing();
  };

  return (
    <div className="flex flex-col space-y-3">
      <div className="flex space-x-2">
        <form className="space-x-2" onSubmit={send}>
          <input
            type="text"
            value={draft}
            placeholder="say something..."
            onChange={(e) => setDraft(e.target.value)}
            className="border rounded px-2 py-1"
          />
          <button
            type="submit"
            className="bg-black rounded text-white px-2 py-1 font-bold cursor-pointer"
          >
            Send
          </button>
        </form>

        <button
          type="button"
          className="bg-black rounded text-white px-2 py-1 font-bold cursor-pointer"
          onClick={() => pushEvent("replace_all", {})}
        >
          Replace all
        </button>
      </div>

      <ul className="flex flex-col space-y-2">
        {messages.map((message) => (
          <li
            key={message.__dom_id}
            className="flex items-center justify-between border-t border-[#eee] py-2"
          >
            {editingId === message.id ? (
              <form className="flex grow space-x-2" onSubmit={saveEdit}>
                <input
                  type="text"
                  value={editText}
                  autoFocus
                  onChange={(e) => setEditText(e.target.value)}
                  className="border rounded px-2 py-1 grow"
                />
                <button
                  type="submit"
                  className="bg-black rounded text-white px-2 py-1 font-bold cursor-pointer"
                >
                  Save
                </button>
                <button
                  type="button"
                  className="border rounded px-2 py-1 font-bold cursor-pointer"
                  onClick={stopEditing}
                >
                  Cancel
                </button>
              </form>
            ) : (
              <>
                <span>{message.text}</span>
                <span className="flex gap-2">
                  <button
                    type="button"
                    className="bg-black rounded text-white px-2 py-1 font-bold cursor-pointer"
                    onClick={() => startEditing(message)}
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    className="bg-black rounded text-white px-2 py-1 font-bold cursor-pointer"
                    onClick={() => pushEvent("delete", { id: message.id })}
                  >
                    Delete
                  </button>
                </span>
              </>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}
