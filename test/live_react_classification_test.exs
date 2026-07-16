defmodule LiveReactClassificationTest do
  use ExUnit.Case

  import LiveReact
  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias LiveReact.Test
  alias Phoenix.LiveView.LiveStream

  def stream_component(assigns) do
    ~H"""
    <.react name="TestComponent" users={@users} title={@title} />
    """
  end

  test "LiveStream values are excluded from props" do
    stream = LiveStream.new(:users, make_ref(), [], [])

    html =
      render_component(&stream_component/1, users: stream, title: "My Page")

    react = Test.get_react(html)

    assert react.props == %{"title" => "My Page"}
  end
end
