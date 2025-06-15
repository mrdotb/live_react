defmodule LiveReactExamplesWeb.LiveLinkUsage do
  use LiveReactExamplesWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6 space-y-8">
      <div class="text-center">
        <h1 class="text-3xl font-bold text-gray-900 mb-2">
          Using Link Component in LiveView Templates
        </h1>
        <p class="text-gray-600">
          This demonstrates using the Link component directly in LiveView templates
          alongside regular Phoenix link helpers.
        </p>
      </div>

      <div class="grid md:grid-cols-2 gap-8">
        <!-- Regular Phoenix Links -->
        <div class="bg-white p-6 rounded-lg shadow-md border">
          <h2 class="text-xl font-semibold text-gray-800 mb-4">
            Regular Phoenix Links
          </h2>
          <div class="space-y-3">
            <div>
              <.link
                href="/simple"
                class="block bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded transition-colors text-center"
              >
                Phoenix href link
              </.link>
            </div>
            <div>
              <.link navigate="/live-counter" class="block bg-purple-500 hover:bg-purple-600 text-white px-4 py-2 rounded transition-colors text-center">
                Phoenix navigate link
              </.link>
            </div>
            <div>
              <.link patch="/link-usage?phoenix=patch" class="block bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded transition-colors text-center">
                Phoenix patch link
              </.link>
            </div>
          </div>
        </div>

        <!-- React Link Components -->
        <div class="bg-white p-6 rounded-lg shadow-md border">
          <h2 class="text-xl font-semibold text-gray-800 mb-4">
            React Link Components
          </h2>
          <div class="space-y-3">
            <div>
              <.react
                name="Link"
                href="/typescript"
                className="block bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded transition-colors text-center"
                socket={@socket}
              >
                React href link
              </.react>
            </div>
            <div>
              <.react
                name="Link"
                navigate="/context"
                className="block bg-purple-500 hover:bg-purple-600 text-white px-4 py-2 rounded transition-colors text-center"
                socket={@socket}
              >
                React navigate link
              </.react>
            </div>
            <div>
              <.react
                name="Link"
                patch="/link-usage?react=patch"
                className="block bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded transition-colors text-center"
                socket={@socket}
              >
                React patch link
              </.react>
            </div>
          </div>
        </div>
      </div>

      <!-- Current State Info -->
      <div class="bg-gray-50 p-6 rounded-lg">
        <h2 class="text-xl font-semibold text-gray-800 mb-4">
          Current State
        </h2>
        <div class="space-y-2">
          <p><strong>URL Params:</strong> <%= inspect(@params) %></p>
          <p><strong>LiveView Process:</strong> <%= inspect(self()) %></p>

          <%= if @params["phoenix"] do %>
            <div class="mt-4 p-3 bg-blue-100 border border-blue-300 rounded">
              <p class="text-blue-800">
                🔵 Navigated here via Phoenix <%= @params["phoenix"] %> link
              </p>
            </div>
          <% end %>

          <%= if @params["react"] do %>
            <div class="mt-4 p-3 bg-green-100 border border-green-300 rounded">
              <p class="text-green-800">
                ⚛️ Navigated here via React <%= @params["react"] %> link
              </p>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Back to Examples -->
      <div class="text-center">
        <.react
          name="Link"
          navigate="/link-demo"
          className="bg-gray-600 hover:bg-gray-700 text-white px-6 py-3 rounded-lg transition-colors"
          socket={@socket}
        >
          ← Back to Link Demo
        </.react>
      </div>
    </div>
    """
  end

  def mount(_session, _params, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    socket = assign(socket, params: params)
    {:noreply, socket}
  end
end
