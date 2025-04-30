defmodule LiveReactExamplesWeb.LiveSlot do
  use LiveReactExamplesWeb, :live_view

  def render(assigns) do
    ~H"""
    <h1 class="flex justify-center mb-10 font-bold">Slot</h1>
    <.react name="Slot" socket={@socket} ssr={true}>
      <div>button component passed as a slot and rendered</div>
      <.button class="cursor-pointer">
        button
      </.button>
    </.react>
    """
  end

  def mount(_session, _params, socket) do
    {:ok, assign(socket, :count, 10)}
  end

  def handle_event("set_count", %{"value" => number}, socket) do
    {:noreply, assign(socket, :count, String.to_integer(number))}
  end
end
