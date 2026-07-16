export function StreamDemo({ messages = [], pushEvent }) {
  return (
    <div className="flex flex-col space-y-3">
      <button
        type="button"
        className="bg-black rounded text-white px-2 py-1 font-bold cursor-pointer w-fit"
        onClick={() => pushEvent("add", {})}
      >
        Add message
      </button>

      <ul className="flex flex-col space-y-2">
        {messages.map((message) => (
          <li
            key={message.__dom_id}
            className="flex items-center justify-between border-t border-[#eee] py-2"
          >
            <span>{message.text}</span>
            <span className="flex gap-2">
              <button
                type="button"
                className="bg-black rounded text-white px-2 py-1 font-bold cursor-pointer"
                onClick={() => pushEvent("update", { id: message.id })}
              >
                Update
              </button>
              <button
                type="button"
                className="bg-black rounded text-white px-2 py-1 font-bold cursor-pointer"
                onClick={() => pushEvent("delete", { id: message.id })}
              >
                Delete
              </button>
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}
