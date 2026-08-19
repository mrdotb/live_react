defmodule LiveReact do
  @moduledoc """
  See READ.md for installation instructions and examples.
  """

  use Phoenix.Component
  import Phoenix.HTML

  alias LiveReact.Encoder
  alias LiveReact.Patch
  alias LiveReact.SSR
  alias LiveReact.Slots
  alias Phoenix.LiveView
  alias Phoenix.LiveView.LiveStream

  require Logger

  @ssr_default Application.compile_env(:live_react, :ssr, true)
  @diff_default Application.compile_env(:live_react, :enable_props_diff, true)

  @doc """
  Render a React component.
  """
  def react(assigns) do
    flags = render_flags(assigns)
    assigns = prepare_assigns(assigns, flags)

    # It's important to not add extra `\n` in the inner div or it will break hydration
    ~H"""
    <div
      id={assigns[:id] || id(@__component_name)}
      data-name={@__component_name}
      data-props={"#{Patch.encode_object(Encoder.encode(@props))}"}
      data-props-diff={"#{@props_diff}"}
      data-streams-diff={"#{@streams_diff}"}
      data-slots={"#{@slots |> Slots.base_encode_64 |> json}"}
      data-ssr={is_map(@ssr_render)}
      data-use-diff={@use_diff |> to_string()}
      phx-update="ignore"
      phx-hook="ReactHook"
      class={@class}
    ><%= raw(@ssr_render[:html]) %></div>
    """
  end

  # Flags derived from the assigns that drive how the component is rendered.
  defp render_flags(assigns) do
    init = assigns.__changed__ == nil
    dead = assigns[:socket] == nil or not LiveView.connected?(assigns[:socket])

    %{
      init: init,
      dead: dead,
      diff: Map.get(assigns, :diff, @diff_default),
      streams_diff: Enum.any?(assigns, fn {_k, v} -> match?(%LiveStream{}, v) end),
      ssr: init and dead and Map.get(assigns, :ssr, @ssr_default)
    }
  end

  # Builds the assigns consumed by the template: props, diffs, slots and SSR output.
  defp prepare_assigns(assigns, flags) do
    base_assigns =
      if flags.diff do
        Enum.filter(assigns, fn {k, _v} -> key_changed(assigns, k) end)
      else
        assigns
      end

    {props, _} = extract(base_assigns, assigns, :props)
    {streams, _} = extract(base_assigns, assigns, :streams)
    {slots, slots_changed?} = extract(assigns, assigns, :slots)

    props_diff = if flags.diff, do: calculate_props_diff(props, assigns), else: []

    streams_diff =
      if flags.streams_diff,
        do: calculate_streams_diff(streams, flags.init or flags.dead),
        else: []

    assigns
    |> Map.put_new(:class, nil)
    |> Map.put(:__component_name, Map.get(assigns, :name))
    |> Map.put(:props, props)
    |> Map.put(:props_diff, Patch.serialize(props_diff))
    |> Map.put(:streams_diff, Patch.serialize(streams_diff))
    |> Map.put(:use_diff, flags.diff)
    |> Map.put(:slots, if(slots_changed?, do: Slots.rendered_slot_map(slots), else: %{}))
    |> put_ssr_render(flags)
    |> mark_computed_changed(flags, slots_changed?)
  end

  defp put_ssr_render(assigns, flags) do
    Map.put(assigns, :ssr_render, if(flags.ssr, do: ssr_render(assigns), else: nil))
  end

  # Marks the assigns we computed ourselves as changed so LiveView diffs them.
  defp mark_computed_changed(assigns, flags, slots_changed?) do
    full_props? = flags.init or flags.dead or not flags.diff

    computed_changed = %{
      props: full_props?,
      slots: slots_changed?,
      ssr_render: flags.ssr,
      props_diff: not full_props?,
      streams_diff: flags.streams_diff
    }

    update_in(assigns.__changed__, fn
      nil -> nil
      changed -> for {k, true} <- computed_changed, into: changed, do: {k, true}
    end)
  end

  # Calculates minimal JSON Patch operations for changed props only.
  # Uses Phoenix LiveView's __changed__ tracking to identify what props have changed.
  defp calculate_props_diff(props, %{__changed__: changed}) do
    props
    |> Enum.flat_map(fn {k, new_value} ->
      case changed[k] do
        nil ->
          []

        true ->
          [%{op: "replace", path: "/#{k}", value: Encoder.encode(new_value)}]

        old_value ->
          Jsonpatch.diff(old_value, new_value,
            ancestor_path: "/#{k}",
            prepare_map: fn
              struct when is_struct(struct) -> Encoder.encode(struct)
              rest -> rest
            end,
            object_hash: &object_hash/1
          )
      end
    end)
    |> then(fn diff -> [%{op: "test", path: "", value: :rand.uniform(10_000_000)} | diff] end)
  end

  defp object_hash(%{id: id}), do: id
  defp object_hash(_), do: nil

  # Generates JSON patch operations for LiveStream changes.
  # Handles insertions and deletions for Phoenix LiveView streams.
  defp calculate_streams_diff(streams, initial)

  defp calculate_streams_diff(streams, true) do
    # for initial render, we want to reset all streams, and then apply the diffs
    init = Enum.map(streams, fn {k, _} -> %{op: "replace", path: "/#{k}", value: []} end)
    diffs = Enum.flat_map(streams, fn {k, stream} -> generate_stream_patches(k, stream) end)
    init ++ diffs
  end

  defp calculate_streams_diff(streams, false) do
    streams
    |> Enum.flat_map(fn {k, stream} -> generate_stream_patches(k, stream) end)
    |> then(fn diff -> [%{op: "test", path: "", value: :rand.uniform(10_000_000)} | diff] end)
  end

  # Generates JSON patch operations for a single LiveStream's changes.
  defp generate_stream_patches(stream_name, %LiveStream{} = stream) do
    patches = []

    patches =
      if stream.reset?,
        do: [%{op: "replace", path: "/#{stream_name}", value: []} | patches],
        else: patches

    patches =
      Enum.reduce(stream.deletes, patches, fn dom_id, patches ->
        [%{op: "remove", path: "/#{stream_name}/$$#{dom_id}"} | patches]
      end)

    # Reversed - inserts at -1 should be correctly ordered, inserts at 0 should be reversed
    # see https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#stream/4 :at option
    stream.inserts
    |> Enum.reverse()
    |> Enum.reduce(patches, fn {dom_id, at, item, limit, update_only}, patches ->
      item = Map.put(Encoder.encode(item), :__dom_id, dom_id)

      patches =
        if update_only,
          do: [%{op: "replace", path: "/#{stream_name}/$$#{dom_id}", value: item} | patches],
          else: [
            %{
              op: "upsert",
              path: "/#{stream_name}/#{if at == -1, do: "-", else: at}",
              value: item
            }
            | patches
          ]

      if limit,
        do: [%{op: "limit", path: "/#{stream_name}", value: limit} | patches],
        else: patches
    end)
    |> Enum.reverse()
  end

  # `iterable` is the (possibly diff-filtered) collection of assigns to bucket by `type`.
  # `source` is always the original, unfiltered assigns map (with `__changed__` intact),
  # used for the `key_changed/2` lookups below regardless of what `iterable` is.
  defp extract(iterable, source, type) do
    Enum.reduce(iterable, {%{}, false}, fn {key, value}, {acc, changed} ->
      case normalize_key(key, value) do
        ^type -> {Map.put(acc, key, value), changed || key_changed(source, key)}
        _ -> {acc, changed}
      end
    end)
  end

  defp normalize_key(key, _val)
       when key in ~w(id class ssr diff name socket __changed__ __given__)a,
       do: :special

  defp normalize_key(_key, [%{__slot__: _}]), do: :slots
  defp normalize_key(key, val) when is_atom(key), do: key |> to_string() |> normalize_key(val)
  defp normalize_key(_key, %LiveStream{}), do: :streams
  defp normalize_key(_key, _val), do: :props

  defp key_changed(%{__changed__: nil}, _key), do: true
  defp key_changed(%{__changed__: changed}, key), do: changed[key] != nil

  defp ssr_render(assigns) do
    try do
      name = Map.get(assigns, :name)

      SSR.render(name, Encoder.encode(assigns.props), assigns.slots)
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
