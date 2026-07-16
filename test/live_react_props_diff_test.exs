defmodule LiveReactPropsDiffTest do
  use ExUnit.Case

  import Phoenix.Component

  alias LiveReact.Test

  defp render_react_assigns(assigns) do
    rendered = LiveReact.react(assigns)
    html = rendered |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    Test.get_react(html)
  end

  defp assert_patches_equal(actual, expected) do
    actual_sorted = actual |> decode_patch() |> Enum.sort_by(& &1["path"])
    expected_sorted = Enum.sort_by(expected, & &1["path"])
    assert actual_sorted == expected_sorted
  end

  defp decode_patch(patch_list) do
    patch_list
    |> Enum.map(fn
      [op, path] -> %{"op" => op, "path" => path}
      [op, path, value] -> %{"op" => op, "path" => path, "value" => value}
    end)
    |> Enum.reject(&(&1["op"] == "test"))
  end

  describe "props_diff functionality" do
    test "initial render has empty props_diff and use_diff true" do
      assigns = %{username: "John", age: 30, socket: nil, __changed__: nil}

      react = render_react_assigns(assigns)

      assert react.props == %{"username" => "John", "age" => 30}
      assert react.use_diff == true
      assert_patches_equal(react.props_diff, [])
    end

    test "single simple prop change creates replace operation" do
      assigns = %{username: "John", age: 30, __changed__: %{}}
      assigns = assign(assigns, :username, "Jane")

      react = render_react_assigns(assigns)

      assert_patches_equal(react.props_diff, [
        %{"op" => "replace", "path" => "/username", "value" => "Jane"}
      ])
    end

    test "complex prop changes use Jsonpatch.diff for minimal operations" do
      assigns = %{user: %{name: "John", age: 30}, __changed__: %{}}
      assigns = assign(assigns, :user, %{name: "Alice", age: 25})

      react = render_react_assigns(assigns)

      assert_patches_equal(react.props_diff, [
        %{"op" => "replace", "path" => "/user/age", "value" => 25},
        %{"op" => "replace", "path" => "/user/name", "value" => "Alice"}
      ])
    end

    test "unchanged props do not appear in diff" do
      assigns = %{username: "John", age: 30, __changed__: %{}}
      assigns = assign(assigns, :username, "Bob")

      react = render_react_assigns(assigns)

      assert_patches_equal(react.props_diff, [
        %{"op" => "replace", "path" => "/username", "value" => "Bob"}
      ])
    end

    test "lists are diffed based on id field" do
      assigns = %{
        items: [%{id: 1, name: "Alice"}, %{id: 2, name: "Bob"}],
        __changed__: %{}
      }

      assigns = assign(assigns, :items, [%{id: 1, name: "Alice"}, %{id: 2, name: "New Bob"}])

      react = render_react_assigns(assigns)

      assert_patches_equal(react.props_diff, [
        %{"op" => "replace", "path" => "/items/1/name", "value" => "New Bob"}
      ])
    end

    test "it's possible to disable diffs per-instance" do
      assigns = %{user: %{name: "John", age: 30}, diff: false, __changed__: %{}}
      assigns = assign(assigns, :user, %{name: "Jane", age: 25})

      react = render_react_assigns(assigns)

      assert react.use_diff == false
      assert react.props == %{"user" => %{"name" => "Jane", "age" => 25}}
      assert_patches_equal(react.props_diff, [])
    end

    defmodule User do
      @moduledoc false
      @derive LiveReact.Encoder
      defstruct [:name, :age]
    end

    test "for structs uses LiveReact.Encoder to convert to map" do
      assigns = %{user: %User{name: "John", age: 30}, __changed__: %{}}
      assigns = assign(assigns, :user, %User{name: "Alice", age: 25})

      react = render_react_assigns(assigns)

      assert_patches_equal(react.props_diff, [
        %{"op" => "replace", "path" => "/user/age", "value" => 25},
        %{"op" => "replace", "path" => "/user/name", "value" => "Alice"}
      ])
    end

    test "struct props without LiveReact.Encoder raise a helpful error" do
      defmodule Undecoded do
        @moduledoc false
        defstruct [:name]
      end

      assigns = %{user: struct!(Undecoded, name: "John"), __changed__: nil}

      assert_raise Protocol.UndefinedError,
                   ~r/LiveReact.Encoder protocol must always be explicitly implemented/,
                   fn ->
                     render_react_assigns(assigns)
                   end
    end
  end
end
