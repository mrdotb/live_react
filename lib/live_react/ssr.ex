defmodule LiveReact.SSR.NotConfigured do
  @moduledoc false

  defexception [:message]
end

defmodule LiveReact.SSR do
  require Logger

  @moduledoc """
  A behaviour for rendering React components server-side.

  To define a custom renderer, change the application config in `config.exs`:

      config :live_react, ssr_module: MyCustomSSRModule

  Exposes a telemetry span for each render under key `[:live_react, :ssr]`
  """

  @type component_name :: String.t()
  @type props :: %{optional(String.t() | atom) => any}

  @typedoc """
  A render response which should have shape

  %{
    html: string,
  }
  """
  @type render_response :: %{optional(String.t() | atom) => any}

  @callback render(component_name, props) :: render_response | no_return

  @spec render(component_name, props) :: render_response | no_return
  def render(name, props) do
    case Application.get_env(:live_react, :ssr_module, nil) do
      nil ->
        %{html: ""}

      mod ->
        meta = %{component: name, props: props}

        body =
          :telemetry.span([:live_react, :ssr], meta, fn ->
            {mod.render(name, props), meta}
          end)

        %{html: body}
    end
  end
end
