defmodule LiveReactExamplesWeb.LiveStreamDemo do
  use LiveReactExamplesWeb, :live_view

  @chatter [
    "turns out it was DNS. it's always DNS.",
    "who deployed on a friday 👀",
    "works on my machine 🤷",
    "brb, cat is standing on the keyboard",
    "I renamed one variable and now nothing compiles",
    "the bug fixed itself. I don't trust it.",
    "standup in 2 minutes, everyone look busy",
    "coffee count: 4. regrets: 0.",
    "my PR is 4000 lines, sorry not sorry",
    "I'll write the tests later (narrator: they did not)",
    "reverting. we never speak of this again.",
    "TODO: remove this TODO",
    "the server isn't down, it's just resting",
    "did anyone else's tests suddenly pass? suspicious.",
    "just one more if statement, it's fine",
    "ship it 🚢",
    "who left a console.log in production",
    "my rubber duck resigned this morning"
  ]

  def render(assigns) do
    ~H"""
    <.react name="StreamDemo" messages={@streams.messages} socket={@socket} />
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:next_id, 1)
      |> stream(:messages, [%{id: 0, text: "hey, anyone here? 👋"}])

    {:ok, socket}
  end

  # A brand new message is appended to the stream.
  def handle_event("add", params, socket) do
    id = socket.assigns.next_id

    socket =
      socket
      |> assign(:next_id, id + 1)
      |> stream_insert(:messages, %{id: id, text: message_text(params)})

    {:noreply, socket}
  end

  # `update_only: true` patches a message that is already on the page,
  # without moving it or re-inserting it if it's gone.
  def handle_event("edit", %{"id" => id} = params, socket) do
    message = %{id: id, text: message_text(params)}

    {:noreply, stream_insert(socket, :messages, message, update_only: true)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    {:noreply, stream_delete(socket, :messages, %{id: id})}
  end

  # `reset: true` throws the whole conversation away and starts a new one.
  def handle_event("replace_all", _params, socket) do
    id = socket.assigns.next_id

    messages =
      @chatter
      |> Enum.shuffle()
      |> Enum.take(3)
      |> Enum.with_index(id)
      |> Enum.map(fn {text, index} -> %{id: index, text: text} end)

    socket =
      socket
      |> assign(:next_id, id + length(messages))
      |> stream(:messages, messages, reset: true)

    {:noreply, socket}
  end

  defp message_text(%{"text" => text}) do
    case String.trim(text) do
      "" -> Enum.random(@chatter)
      text -> text
    end
  end

  defp message_text(_params), do: Enum.random(@chatter)
end
