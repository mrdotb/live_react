defmodule LiveReactExamplesWeb.LiveDemoAssigns do
  @moduledoc """
  Assigns the current demo state.
  """

  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    socket = attach_hook(socket, :active_tab, :handle_params, &set_active_demo/3)
    {:cont, socket}
  end

  defp set_active_demo(_params, _url, socket) do
    demo =
      case {socket.view, socket.assigns.live_action} do
        {LiveReactExamplesWeb.LiveCounter, _} ->
          :counter

        {LiveReactExamplesWeb.LiveLogList, _} ->
          :log_list

        {_view, _live_action} ->
          nil
      end

    {:cont, assign(socket, demo: demo)}
  end
end
