defmodule LiveReactExamplesWeb.LiveLinkDemo do
  use LiveReactExamplesWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100">
      <.react
        name="LinkExample"
        currentPath={@current_path}
        socket={@socket}
        ssr={true}
      />

      <div class="max-w-4xl mx-auto px-6 pb-8">
        <div class="bg-white p-6 rounded-lg shadow-md border">
          <h2 class="text-xl font-semibold text-gray-800 mb-4">
            LiveView State Information
          </h2>
          <div class="space-y-2">
            <p><strong>Current Path:</strong> <%= @current_path %></p>
            <p><strong>Current Tab:</strong> <%= @current_tab %></p>
            <p><strong>URL Params:</strong> <%= inspect(@params) %></p>
            <p><strong>LiveView Process:</strong> <%= inspect(self()) %></p>
            <p><strong>Mount Count:</strong> <%= @mount_count %></p>
            <p><strong>Params Update Count:</strong> <%= @params_update_count %></p>
          </div>

          <%= if @params["replaced"] do %>
            <div class="mt-4 p-3 bg-yellow-100 border border-yellow-300 rounded">
              <p class="text-yellow-800">
                🔄 This page was reached via history replace - check your browser's back button!
              </p>
            </div>
          <% end %>

          <%= if @params["reset"] do %>
            <div class="mt-4 p-3 bg-green-100 border border-green-300 rounded">
              <p class="text-green-800">
                ✅ This demonstrates patch navigation - same process, different params!
              </p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def mount(_session, _params, socket) do
    # Get the mount count from process dictionary to track mounts
    mount_count = Process.get(:mount_count, 0) + 1
    Process.put(:mount_count, mount_count)

    socket = assign(socket,
      mount_count: mount_count,
      params_update_count: 0
    )

    {:ok, socket}
  end

  def handle_params(params, uri, socket) do
    # Extract the path from the URI
    %{path: path} = URI.parse(uri)
    current_tab = params["tab"] || "default"

    socket = assign(socket,
      current_path: path,
      current_tab: current_tab,
      params: params,
      params_update_count: socket.assigns.params_update_count + 1
    )

    {:noreply, socket}
  end
end
