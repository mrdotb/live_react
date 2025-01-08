defmodule LiveReact.Reload do
  @moduledoc """
  Utilities for easier integration with Vite in development
  """

  use Phoenix.Component

  attr(:assets, :list, required: true)
  slot(:inner_block, required: true, doc: "what should be rendered when Vite path is not defined")

  @doc """
  Renders the vite assets in development, and in production falls back to normal compiled assets
  """
  def vite_assets(assigns) do
    assigns =
      assigns
      |> assign(
        :stylesheets,
        for(path <- assigns.assets, String.ends_with?(path, ".css"), do: path)
      )
      |> assign(
        :javascripts,
        for(
          path <- assigns.assets,
          String.ends_with?(path, ".js") || String.ends_with?(path, ".ts"),
          do: path
        )
      )

    # TODO - maybe make it configurable in other way than by presence of vite_host config?
    # https://vitejs.dev/guide/backend-integration.html
    ~H"""
    <%= if Application.get_env(:live_react, :vite_host) do %>
      <script type="module">
        import RefreshRuntime from '<%= LiveReact.SSR.ViteJS.vite_path("@react-refresh") %>'
        RefreshRuntime.injectIntoGlobalHook(window)
        window.$RefreshReg$ = () => {}
        window.$RefreshSig$ = () => (type) => type
        window.__vite_plugin_react_preamble_installed__ = true
      </script>
      <script type="module" src={LiveReact.SSR.ViteJS.vite_path("@vite/client")}>
      </script>
      <link :for={path <- @stylesheets} rel="stylesheet" href={LiveReact.SSR.ViteJS.vite_path(path)} />
      <script :for={path <- @javascripts} type="module" src={LiveReact.SSR.ViteJS.vite_path(path)}>
      </script>
    <% else %>
      <%= render_slot(@inner_block) %>
    <% end %>
    """
  end
end
