defmodule LiveReactExamples do
  @moduledoc """
  LiveReactExamples keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @url "https://github.com/mrdotb/live_react/blob/main/live_react_examples"
  @raw_url "https://raw.githubusercontent.com/mrdotb/live_react/main/live_react_examples"
  @dead_views "/lib/live_react_examples_web/controllers/page_html"
  @live_views "/lib/live_react_examples_web/live"
  @react "/assets/react-components"

  @demo_defaults %{
    view_type: "LiveView",
    view_language: "heex",
    react_language: "jsx"
  }

  @doc """
  Returns the source urls and languages powering the `demo` tab of a page.

  Every key of `@demo_defaults` is always present, so callers can read them
  directly instead of relying on component attribute defaults.
  """
  def demo(name), do: Map.merge(@demo_defaults, demo_urls(name))

  defp demo_urls(name)

  defp demo_urls(:simple) do
    %{
      view_type: "DeadView",
      raw_view_url: "#{@raw_url}/#{@dead_views}/simple.html.heex",
      view_url: "#{@url}/#{@dead_views}/simple.html.heex",
      raw_react_url: "#{@raw_url}/#{@react}/simple.jsx",
      react_url: "#{@url}/#{@react}/simple.jsx"
    }
  end

  defp demo_urls(:simple_props) do
    %{
      view_type: "DeadView",
      raw_view_url: "#{@raw_url}/#{@dead_views}/simple_props.html.heex",
      view_url: "#{@url}/#{@dead_views}/simple_props.html.heex",
      raw_react_url: "#{@raw_url}/#{@react}/simple-props.jsx",
      react_url: "#{@url}/#{@react}/simple-props.jsx"
    }
  end

  defp demo_urls(:typescript) do
    %{
      view_type: "DeadView",
      raw_view_url: "#{@raw_url}#{@dead_views}/typescript.html.heex",
      view_url: "#{@url}#{@dead_views}/typescript.html.heex",
      raw_react_url: "#{@raw_url}#{@react}/typescript.tsx",
      react_url: "#{@url}#{@react}/typescript.tsx",
      react_language: "tsx"
    }
  end

  defp demo_urls(:lazy) do
    %{
      view_type: "DeadView",
      raw_view_url: "#{@raw_url}#{@dead_views}/lazy.html.heex",
      view_url: "#{@url}#{@dead_views}/lazy.html.heex",
      raw_react_url: "#{@raw_url}#{@react}/lazy.jsx",
      react_url: "#{@url}#{@react}/lazy.jsx"
    }
  end

  defp demo_urls(:counter) do
    %{
      raw_view_url: "#{@raw_url}#{@live_views}/counter.ex",
      view_url: "#{@url}#{@live_views}/counter.ex",
      view_language: "elixir",
      raw_react_url: "#{@raw_url}#{@react}/counter.jsx",
      react_url: "#{@url}#{@react}/counter.jsx"
    }
  end

  defp demo_urls(:log_list) do
    %{
      raw_view_url: "#{@raw_url}#{@live_views}/log_list.ex",
      view_url: "#{@url}#{@live_views}/log_list.ex",
      view_language: "elixir",
      raw_react_url: "#{@raw_url}#{@react}/log-list.jsx",
      react_url: "#{@url}#{@react}/log-list.jsx"
    }
  end

  defp demo_urls(:flash_sonner) do
    %{
      raw_view_url: "#{@raw_url}#{@live_views}/flash_sonner.ex",
      view_url: "#{@url}#{@live_views}/flash_sonner.ex",
      view_language: "elixir",
      raw_react_url: "#{@raw_url}#{@react}/flash-sonner.jsx",
      react_url: "#{@url}#{@react}/flash-sonner.jsx"
    }
  end

  defp demo_urls(:ssr) do
    %{
      raw_view_url: "#{@raw_url}#{@live_views}/ssr.ex",
      view_url: "#{@url}#{@live_views}/ssr.ex",
      view_language: "elixir",
      raw_react_url: "#{@raw_url}#{@react}/ssr.jsx",
      react_url: "#{@url}#{@react}/ssr.jsx"
    }
  end

  defp demo_urls(:hybrid_form) do
    %{
      raw_view_url: "#{@raw_url}#{@live_views}/hybrid_form.ex",
      view_url: "#{@url}#{@live_views}/hybrid_form.ex",
      view_language: "elixir",
      raw_react_url: "#{@raw_url}#{@react}/delay-slider.tsx",
      react_url: "#{@url}#{@react}/delay-slider.tsx"
    }
  end

  defp demo_urls(:slot) do
    %{
      raw_view_url: "#{@raw_url}#{@live_views}/slot.ex",
      view_url: "#{@url}#{@live_views}/slot.ex",
      view_language: "elixir",
      raw_react_url: "#{@raw_url}#{@react}/slot.tsx",
      react_url: "#{@url}#{@react}/slot.tsx"
    }
  end

  defp demo_urls(:context) do
    %{
      raw_view_url: "#{@raw_url}#{@live_views}/context.ex",
      view_url: "#{@url}#{@live_views}/context.ex",
      view_language: "elixir",
      raw_react_url: "#{@raw_url}#{@react}/context.tsx",
      react_url: "#{@url}#{@react}/context.tsx"
    }
  end

  defp demo_urls(:link_demo) do
    %{
      raw_view_url: "#{@raw_url}#{@live_views}/link_demo.ex",
      view_url: "#{@url}#{@live_views}/link_demo.ex",
      view_language: "elixir",
      raw_react_url: "#{@raw_url}#{@react}/link-example.jsx",
      react_url: "#{@url}#{@react}/link-example.jsx"
    }
  end

  defp demo_urls(:link_usage) do
    %{
      raw_view_url: "#{@raw_url}#{@live_views}/link_usage.ex",
      view_url: "#{@url}#{@live_views}/link_usage.ex",
      view_language: "elixir",
      raw_react_url: "#{@raw_url}#{@react}/link.jsx",
      react_url: "#{@url}#{@react}/link.jsx"
    }
  end

  defp demo_urls(:stream_demo) do
    %{
      raw_view_url: "#{@raw_url}#{@live_views}/stream_demo.ex",
      view_url: "#{@url}#{@live_views}/stream_demo.ex",
      view_language: "elixir",
      raw_react_url: "#{@raw_url}#{@react}/stream-demo.jsx",
      react_url: "#{@url}#{@react}/stream-demo.jsx"
    }
  end

  defp demo_urls(demo) do
    raise ArgumentError, "Unknown demo: #{inspect(demo)}"
  end
end
