defmodule LiveReactExamplesWeb.LiveLogList do
  use LiveReactExamplesWeb, :live_view

  def render(assigns) do
    ~H"""
    <.react name="LogList" socket={@socket} />
    """
  end

  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(1000, self(), :tick)
    {:ok, socket}
  end

  def handle_event("add_item", %{"body" => body}, socket) do
    socket = push_event(socket, "new_item", create_log(body))
    {:noreply, socket}
  end

  def handle_info(:tick, socket) do
    datetime =
      DateTime.utc_now()
      |> DateTime.to_string()

    socket = push_event(socket, "new_item", create_log(datetime))
    {:noreply, socket}
  end

  defp create_log(body) do
    %{id: System.unique_integer([:positive]), body: body}
  end
end
