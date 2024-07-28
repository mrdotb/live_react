defmodule LiveReactExamplesWeb.PageController do
  use LiveReactExamplesWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/simple")
  end

  def simple(conn, _params) do
    render(conn, :simple, demo: :simple)
  end

  def simple_props(conn, _params) do
    render(conn, :simple_props, demo: :simple_props)
  end

  def typescript(conn, _params) do
    render(conn, :typescript, demo: :typescript)
  end

  def lazy(conn, _params) do
    render(conn, :lazy, demo: :lazy)
  end
end
