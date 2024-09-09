defmodule LiveReactExamplesWeb.LiveCounter do
  use LiveReactExamplesWeb, :live_view

  def render(assigns) do
    ~H"""
    <h1 class="flex justify-center mb-10 font-bold">Hybrid: LiveView + React</h1>
    <.react name="Counter" count={@count} socket={@socket} ssr={true} />
    """
  end

  def mount(_session, _params, socket) do
    {:ok, assign(socket, :count, 10)}
  end

  def handle_event("set_count", %{"value" => number}, socket) do
    {:noreply, assign(socket, :count, String.to_integer(number))}
  end
end
