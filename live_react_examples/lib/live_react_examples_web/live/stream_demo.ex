defmodule LiveReactExamplesWeb.LiveStreamDemo do
  use LiveReactExamplesWeb, :live_view

  def render(assigns) do
    ~H"""
    <.react name="StreamDemo" messages={@streams.messages} socket={@socket} />
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:next_id, 1)
      |> stream(:messages, [%{id: 0, text: "Welcome!"}])

    {:ok, socket}
  end

  def handle_event("add", _params, socket) do
    id = socket.assigns.next_id

    socket =
      socket
      |> assign(:next_id, id + 1)
      |> stream_insert(:messages, %{id: id, text: "Message #{id}"})

    {:noreply, socket}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    {:noreply, stream_delete(socket, :messages, %{id: id})}
  end

  def handle_event("update", %{"id" => id}, socket) do
    text = "Message #{id} updated at #{Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")}"

    {:noreply, stream_insert(socket, :messages, %{id: id, text: text})}
  end
end
