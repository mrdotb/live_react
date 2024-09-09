defmodule LiveReact do
  @moduledoc """
  See READ.md for installation instructions and examples.
  """

  use Phoenix.Component
  import Phoenix.HTML

  alias Phoenix.LiveView
  alias LiveReact.SSR

  require Logger

  @doc """
  Render a React component.
  """
  def react(assigns) do
    init = assigns.__changed__ == nil
    dead = assigns[:socket] == nil or not LiveView.connected?(assigns[:socket])
    render_ssr? = init and dead and Map.get(assigns, :ssr, false)

    # we manually compute __changed__ for the computed props and slots so it's not sent without reason
    {props, props_changed?} = extract(assigns, :props)
    component_name = Map.get(assigns, :name)

    assigns =
      assigns
      |> Map.put_new(:class, nil)
      |> Map.put(:__component_name, component_name)
      |> Map.put(:props, props)
      |> Map.put(:ssr_render, if(render_ssr?, do: ssr_render(component_name, props), else: nil))

    computed_changed =
      %{
        props: props_changed?,
        ssr_render: render_ssr?
      }

    assigns =
      update_in(assigns.__changed__, fn
        nil -> nil
        changed -> for {k, true} <- computed_changed, into: changed, do: {k, true}
      end)

    # It's important to not add extra `\n` in the inner div or it will break hydration
    ~H"""
    <div
      id={assigns[:id] || id(@__component_name)}
      data-name={@__component_name}
      data-props={"#{json(@props)}"}
      data-ssr={is_map(@ssr_render)}
      phx-update="ignore"
      phx-hook="ReactHook"
      class={@class}
    ><%= raw(@ssr_render[:html]) %></div>
    """
  end

  defp extract(assigns, type) do
    Enum.reduce(assigns, {%{}, false}, fn {key, value}, {acc, changed} ->
      case normalize_key(key, value) do
        ^type -> {Map.put(acc, key, value), changed || key_changed(assigns, key)}
        _ -> {acc, changed}
      end
    end)
  end

  defp normalize_key(key, _val) when key in ~w(id class ssr name socket __changed__ __given__)a,
    do: :special

  defp normalize_key(key, val) when is_atom(key), do: key |> to_string() |> normalize_key(val)
  defp normalize_key(_key, _val), do: :props

  defp key_changed(%{__changed__: nil}, _key), do: true
  defp key_changed(%{__changed__: changed}, key), do: changed[key] != nil

  defp ssr_render(name, props) do
    try do
      SSR.render(name, props)
    rescue
      SSR.NotConfigured ->
        nil
    end
  end

  defp json(data), do: Jason.encode!(data, escape: :html_safe)

  defp id(name) do
    # a small trick to avoid collisions of IDs but keep them consistent across dead and live render
    # id(name) is called only once during the whole LiveView lifecycle because it's not using any assigns
    number = Process.get(:live_react_counter, 1)
    Process.put(:live_react_counter, number + 1)
    "#{name}-#{number}"
  end
end
