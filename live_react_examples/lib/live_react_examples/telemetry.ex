defmodule LiveReactExamples.Telemetry do
  require Logger

  def setup() do
    :ok =
      :telemetry.attach(
        "live-react-ssr-logger",
        [:live_react, :ssr, :stop],
        &LiveReactExamples.Telemetry.handle_event/4,
        nil
      )
  end

  def handle_event([:live_react, :ssr, :stop], %{duration: duration}, metadata, _config) do
    duration_ms = System.convert_time_unit(duration, :native, :microsecond)
    Logger.info("SSR completed for component: #{metadata.component} in #{duration_ms}µs")
  end
end
