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
  @react "/assets/react"

  def demo(name)

  def demo(:simple) do
    %{
      view_type: "DeadView",
      raw_view_url: "#{@raw_url}/#{@dead_views}/simple.html.heex",
      view_url: "#{@url}/#{@dead_views}/simple.html.heex",
      raw_react_url: "#{@raw_url}/#{@react}/simple.jsx",
      react_url: "#{@url}/#{@react}/simple.jsx"
    }
  end

  def demo(:simple_props) do
    %{
      view_type: "DeadView",
      raw_view_url: "#{@raw_url}/#{@dead_views}/simple_props.html.heex",
      view_url: "#{@url}/#{@dead_views}/simple_props.html.heex",
      raw_react_url: "#{@raw_url}/#{@react}/simple-props.jsx",
      react_url: "#{@url}/#{@react}/simple-props.jsx"
    }
  end

  def demo(:typescript) do
    %{
      view_type: "DeadView",
      raw_view_url: "#{@raw_url}#{@dead_views}/typescript.html.heex",
      view_url: "#{@url}#{@dead_views}/typescript.html.heex",
      raw_react_url: "#{@raw_url}#{@react}/typescript.tsx",
      react_url: "#{@url}#{@react}/typescript.tsx",
      react_language: "tsx"
    }
  end

  def demo(:lazy) do
    %{
      view_type: "DeadView",
      raw_view_url: "#{@raw_url}#{@dead_views}/lazy.html.heex",
      view_url: "#{@url}#{@dead_views}/lazy.html.heex",
      raw_react_url: "#{@raw_url}#{@react}/lazy.jsx",
      react_url: "#{@url}#{@react}/lazy.jsx"
    }
  end

  def demo(:counter) do
    %{
      raw_view_url: "#{@raw_url}#{@live_views}/counter.ex",
      view_url: "#{@url}#{@live_views}/counter.ex",
      view_language: "elixir",
      raw_react_url: "#{@raw_url}#{@react}/counter.jsx",
      react_url: "#{@url}#{@react}/counter.jsx"
    }
  end

  def demo(:log_list) do
    %{
      raw_view_url: "#{@raw_url}#{@live_views}/log_list.ex",
      view_url: "#{@url}#{@live_views}/log_list.ex",
      view_language: "elixir",
      raw_react_url: "#{@raw_url}#{@react}/log-list.jsx",
      react_url: "#{@url}#{@react}/log-list.jsx"
    }
  end

  def demo(:flash_sonner) do
    %{
      raw_view_url: "#{@raw_url}#{@live_views}/flash_sonner.ex",
      view_url: "#{@url}#{@live_views}/flash_sonner.ex",
      view_language: "elixir",
      raw_react_url: "#{@raw_url}#{@react}/flash-sonner.jsx",
      react_url: "#{@url}#{@react}/flash-sonner.jsx"
    }
  end

  def demo(:ssr) do
    %{
      raw_view_url: "#{@raw_url}#{@live_views}/ssr.ex",
      view_url: "#{@url}#{@live_views}/ssr.ex",
      view_language: "elixir",
      raw_react_url: "#{@raw_url}#{@react}/ssr.jsx",
      react_url: "#{@url}#{@react}/ssr.jsx"
    }
  end

  def demo(demo) do
    raise ArgumentError, "Unknown demo: #{inspect(demo)}"
  end
end
