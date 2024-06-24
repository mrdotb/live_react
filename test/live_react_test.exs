defmodule LiveReactTest do
  use ExUnit.Case
  doctest LiveReact

  test "greets the world" do
    assert LiveReact.hello() == :world
  end
end
