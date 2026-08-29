defmodule LiveReactChangeTrackingTest do
  @moduledoc """
  Covers which attributes LiveView actually *sends* on a re-render.

  The other props-diff tests render the component directly and read the
  attributes off the resulting HTML, where every attribute is always present.
  That cannot catch a bug in `mark_computed_changed/3`, because marking only
  decides what LiveView puts on the wire. Here we ask the `Rendered` struct for
  its dynamic parts with change tracking enabled, so an attribute LiveView
  would skip comes back as `nil`.
  """
  use ExUnit.Case

  import Phoenix.Component

  # The dynamic parts LiveView would actually send, change tracking enabled.
  defp sent(assigns) do
    %Phoenix.LiveView.Rendered{dynamic: dynamic} = LiveReact.react(assigns)

    dynamic.(true)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&IO.iodata_to_binary/1)
  end

  # `data-props` carries a full JSON object; `Patch.encode_object/1` swaps `"` for `^`.
  defp snapshot?(value), do: String.starts_with?(value, "{^")
  defp patch_for_items?(value), do: String.contains?(value, "/items")

  defp updated_assigns(extra) do
    extra
    |> Map.merge(%{name: "T", items: [%{id: 1, title: "a"}], __changed__: %{}})
    |> assign(:items, [%{id: 1, title: "b"}])
  end

  describe "connected re-render" do
    test "sends the diff and does not resend the props snapshot" do
      socket = %Phoenix.LiveView.Socket{transport_pid: self()}

      sent = sent(updated_assigns(%{socket: socket}))

      assert Enum.any?(sent, &patch_for_items?/1)
      refute Enum.any?(sent, &snapshot?/1)
    end

    test "sends the diff even when the call site does not pass socket" do
      # Regression: `dead` used to be true whenever `socket` was absent, which
      # forced the full-props branch forever. `data-props` was resent carrying
      # only the *changed* keys while `data-props-diff` was never marked
      # changed, so a client in diff mode never saw another update.
      sent = sent(updated_assigns(%{}))

      assert Enum.any?(sent, &patch_for_items?/1)
      refute Enum.any?(sent, &snapshot?/1)
    end
  end

  describe "first render" do
    test "sends the full props snapshot, with or without a socket" do
      for extra <- [%{}, %{socket: nil}] do
        assigns = Map.merge(extra, %{name: "T", items: [%{id: 1}], __changed__: nil})

        sent = sent(assigns)

        assert Enum.any?(sent, &snapshot?/1)
        refute Enum.any?(sent, &patch_for_items?/1)
      end
    end
  end
end
