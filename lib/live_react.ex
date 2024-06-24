defmodule LiveReact do
  use Phoenix.Component

  def react(assigns) do
    # we manually compute __changed__ for the computed props and slots so it's not sent without reason
    {props, props_changed?} = extract(assigns, :props)

    assigns =
      assigns
      |> Map.put_new(:class, nil)
      |> Map.put(:__component_name, Map.get(assigns, :name))
      |> Map.put(:props, props)

    computed_changed =
      %{
        props: props_changed?
      }

    assigns =
      update_in(assigns.__changed__, fn
        nil -> nil
        changed -> for {k, true} <- computed_changed, into: changed, do: {k, true}
      end)

    ~H"""
    <div
      id={assigns[:id] || id(@__component_name)}
      data-name={@__component_name}
      data-props={"#{json(@props)}"}
      phx-update="ignore"
      phx-hook="ReactHook"
      class={@class}
    >
    </div>
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

  defp normalize_key(key, _val) when key in ~w(id class name socket __changed__ __given__)a, do: :special
  defp normalize_key(key, val) when is_atom(key), do: key |> to_string() |> normalize_key(val)
  defp normalize_key(_key, _val), do: :props

  defp key_changed(%{__changed__: nil}, _key), do: true
  defp key_changed(%{__changed__: changed}, key), do: changed[key] != nil

  defp json(data), do: Jason.encode!(data, escape: :html_safe)

  defp id(name), do: "#{name}-#{System.unique_integer([:positive])}"
end
