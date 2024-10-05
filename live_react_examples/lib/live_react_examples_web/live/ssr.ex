defmodule LiveReactExamplesWeb.LiveSSR do
  use LiveReactExamplesWeb, :live_view

  def render(assigns) do
    ~H"""
    <h1 class="flex justify-center mb-10 font-bold">SSR</h1>
    <a
      class="mb-4 block underline"
      href="https://github.com/mrdotb/live_react/blob/main/guides/ssr.md"
    >
      SSR guide
    </a>
    <div class="flex space-x-2">
      <.react ssr={true} name="SSR" socket={@socket} text="I am rendered on Server" />
      <.react ssr={false} name="SSR" socket={@socket} text="I am rendered on Client" />
    </div>
    """
  end

  def mount(_session, _params, socket) do
    {:ok, socket}
  end
end
