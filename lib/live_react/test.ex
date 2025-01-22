defmodule LiveReact.Test do
  @moduledoc """
  Helpers for testing LiveReact components and views.

  ## Overview

  LiveReact testing differs from traditional Phoenix LiveView testing in how components
  are rendered and inspected:

  * In Phoenix LiveView testing, you use `Phoenix.LiveViewTest.render_component/2`
    to get the final rendered HTML
  * In LiveReact testing, `render_component/2` returns an unrendered LiveReact root
    element containing the React component's configuration

  This module provides helpers to extract and inspect React component data from the
  LiveReact root element, including:

  * Component name and ID
  * Props passed to the component
  * Event handlers and their operations
  * Server-side rendering (SSR) status
  * Slot content
  * CSS classes

  ## Examples

      # Render a LiveReact component and inspect its properties
      {:ok, view, _html} = live(conn, "/")
      react = LiveReact.Test.get_react(view)

      # Basic component info
      assert react.component == "MyComponent"
      assert react.props["title"] == "Hello"

      # Event handlers
      assert react.handlers["click"] == JS.push("click")

      # SSR status and styling
      assert react.ssr == true
      assert react.class == "my-custom-class"
  """

  @compile {:no_warn_undefined, Floki}

  @doc """
  Extracts React component information from a LiveView or HTML string.

  When multiple React components are present, you can specify which one to extract using
  either the `:name` or `:id` option.

  Returns a map containing the component's configuration:
    * `:component` - The React component name (from `v-component` attribute)
    * `:id` - The unique component identifier (auto-generated or explicitly set)
    * `:props` - The decoded props passed to the component
    * `:handlers` - Map of event handlers (`v-on:*`) and their operations
    * `:slots` - Base64 encoded slot content
    * `:ssr` - Boolean indicating if server-side rendering was performed
    * `:class` - CSS classes applied to the component root element

  ## Options
    * `:name` - Find component by name (from `v-component` attribute)
    * `:id` - Find component by ID

  ## Examples

      # From a LiveView, get first React component
      {:ok, view, _html} = live(conn, "/")
      react = LiveReact.Test.get_react(view)

      # Get specific component by name
      react = LiveReact.Test.get_react(view, name: "MyComponent")

      # Get specific component by ID
      react = LiveReact.Test.get_react(view, id: "my-component-1")
  """
  def get_react(view, opts \\ [])

  def get_react(view, opts) when is_struct(view, Phoenix.LiveViewTest.View) do
    view |> Phoenix.LiveViewTest.render() |> get_react(opts)
  end

  def get_react(html, opts) when is_binary(html) do
    if Code.ensure_loaded?(Floki) do
      react =
        html
        |> Floki.parse_document!()
        |> Floki.find("[phx-hook='ReactHook']")
        |> find_component!(opts)

      %{
        props: Jason.decode!(attr(react, "data-props")),
        component: attr(react, "data-name"),
        id: attr(react, "id"),
        slots: extract_base64_slots(attr(react, "data-slots")),
        ssr: if(is_nil(attr(react, "data-ssr")), do: false, else: true),
        class: attr(react, "class")
      }
    else
      raise "Floki is not installed. Add {:floki, \">= 0.30.0\", only: :test} to your dependencies to use LiveReact.Test"
    end
  end

  defp extract_base64_slots(slots) do
    slots
    |> Jason.decode!()
    |> Enum.map(fn {key, value} -> {key, Base.decode64!(value)} end)
    |> Enum.into(%{})
  end

  defp find_component!(components, opts) do
    available = Enum.map_join(components, ", ", &"#{attr(&1, "data-name")}##{attr(&1, "id")}")

    components =
      Enum.reduce(opts, components, fn
        {:id, id}, result ->
          with [] <- Enum.filter(result, &(attr(&1, "id") == id)) do
            raise "No React component found with id=\"#{id}\". Available components: #{available}"
          end

        {:name, name}, result ->
          with [] <- Enum.filter(result, &(attr(&1, "data-name") == name)) do
            raise "No React component found with name=\"#{name}\". Available components: #{available}"
          end

        {key, _}, _result ->
          raise ArgumentError, "invalid keyword option for get_react/2: #{key}"
      end)

    case components do
      [react | _] ->
        react

      [] ->
        raise "No React components found in the rendered HTML"
    end
  end

  defp attr(element, name) do
    case Floki.attribute(element, name) do
      [value] -> value
      [] -> nil
    end
  end
end
