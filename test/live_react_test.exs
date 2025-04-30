defmodule LiveReactTest do
  use ExUnit.Case

  import LiveReact
  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias LiveReact.Test

  doctest LiveReact

  describe "basic component rendering" do
    def simple_component(assigns) do
      ~H"""
      <.react name="MyComponent" firstName="john" lastName="doe" />
      """
    end

    test "renders component with correct props" do
      html = render_component(&simple_component/1)
      react = Test.get_react(html)

      assert react.component == "MyComponent"
      assert react.props == %{"firstName" => "john", "lastName" => "doe"}
    end

    test "generates consistent ID" do
      html = render_component(&simple_component/1)
      react = Test.get_react(html)

      assert react.id =~ ~r/MyComponent-\d+/
    end
  end

  describe "multiple components" do
    def multi_component(assigns) do
      ~H"""
      <div>
        <.react id="profile-1" firstName="John" name="UserProfile" />
        <.react id="card-1" firstName="Jane" name="UserCard" />
      </div>
      """
    end

    test "finds first component by default" do
      html = render_component(&multi_component/1)
      react = Test.get_react(html)

      assert react.component == "UserProfile"
      assert react.props == %{"firstName" => "John"}
    end

    test "finds specific component by name" do
      html = render_component(&multi_component/1)
      react = Test.get_react(html, name: "UserCard")

      assert react.component == "UserCard"
      assert react.props == %{"firstName" => "Jane"}
    end

    test "finds specific component by id" do
      html = render_component(&multi_component/1)
      react = Test.get_react(html, id: "card-1")

      assert react.component == "UserCard"
      assert react.id == "card-1"
    end

    test "raises error when component with name not found" do
      html = render_component(&multi_component/1)

      assert_raise RuntimeError,
                   ~r/No React component found with name="Unknown".*Available components: UserProfile#profile-1, UserCard#card-1/,
                   fn ->
                     Test.get_react(html, name: "Unknown")
                   end
    end

    test "raises error when component with id not found" do
      html = render_component(&multi_component/1)

      assert_raise RuntimeError,
                   ~r/No React component found with id="unknown-id".*Available components: UserProfile#profile-1, UserCard#card-1/,
                   fn ->
                     Test.get_react(html, id: "unknown-id")
                   end
    end
  end

  describe "styling" do
    def styled_component(assigns) do
      ~H"""
      <.react name="MyComponent" class="bg-blue-500 rounded-sm" />
      """
    end

    test "applies CSS classes" do
      html = render_component(&styled_component/1)
      react = Test.get_react(html)

      assert react.class == "bg-blue-500 rounded-sm"
    end
  end

  describe "SSR behavior" do
    def ssr_component(assigns) do
      ~H"""
      <.react name="MyComponent" ssr={false} />
      """
    end

    test "respects SSR flag" do
      html = render_component(&ssr_component/1)
      react = Test.get_react(html)

      assert react.ssr == false
    end
  end

  describe "slots" do
    def component_with_named_slot(assigns) do
      ~H"""
      <.react name="WithSlots">
        <:hello>Simple content</:hello>
      </.react>
      """
    end

    def component_with_inner_block(assigns) do
      ~H"""
      <.react name="WithSlots">
        Simple content
      </.react>
      """
    end

    test "warns about usage of named slot" do
      assert_raise RuntimeError,
                   "Unsupported slot: hello, only one default slot is supported, passed as React children.",
                   fn -> render_component(&component_with_named_slot/1) end
    end

    test "renders default slot with inner_block" do
      html = render_component(&component_with_inner_block/1)
      react = Test.get_react(html)

      assert react.slots == %{"default" => "Simple content"}
    end

    test "encodes slot as base64" do
      html = render_component(&component_with_inner_block/1)

      # Get raw data-slots attribute to verify base64 encoding
      doc = Floki.parse_fragment!(html)
      slots_attr = Floki.attribute(doc, "data-slots")

      slots =
        slots_attr
        |> Jason.decode!()
        |> Enum.map(fn {key, value} -> {key, Base.decode64!(value)} end)
        |> Enum.into(%{})

      assert slots == %{"default" => "Simple content"}
    end

    test "handles empty slots" do
      html =
        render_component(fn assigns ->
          ~H"""
          <.react name="WithSlots" />
          """
        end)

      react = Test.get_react(html)

      assert react.slots == %{}
    end
  end
end
