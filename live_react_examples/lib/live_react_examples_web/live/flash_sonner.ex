defmodule LiveReactExamplesWeb.LiveFlashSonner do
  use LiveReactExamplesWeb, :live_view

  def render(assigns) do
    ~H"""
    <h1 class="flex justify-center mb-10 font-bold">Flash sonner</h1>
    <.button phx-click="info" class="cursor-pointer">
      info
    </.button>
    <.button phx-click="error" class="cursor-pointer">
      error
    </.button>
    """
  end

  def mount(_session, _params, socket) do
    {:ok, socket}
  end

  def handle_event("info", _params, socket) do
    {:noreply, put_flash(socket, :info, "This is an info message")}
  end

  def handle_event("error", _params, socket) do
    {:noreply, put_flash(socket, :error, "This is an error message")}
  end
end
