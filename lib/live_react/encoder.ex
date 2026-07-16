defprotocol LiveReact.Encoder do
  @moduledoc """
  Protocol for encoding values to JSON for LiveReact.

  This protocol is used to safely transform structs into plain maps before
  calculating JSON patches. It ensures that struct fields are explicitly
  exposed and prevents accidental exposure of sensitive data.

  It's very similar to Jason.Encoder, but it's converting structs to maps instead of strings.

  ## Deriving

  The protocol allows leveraging Elixir's `@derive` feature to simplify protocol
  implementation in trivial cases. Accepted options are:

  * `:only` - encodes only values of specified keys.
  * `:except` - encodes all struct fields except specified keys.

  By default all keys except the `:__struct__` key are encoded.

  ## Example

      defmodule User do
        @derive LiveReact.Encoder
        defstruct [:name, :email, :password]
      end

  If we called `@derive {LiveReact.Encoder, only: [:name, :email]}`, only the
  specified fields would be encoded. If we called
  `@derive {LiveReact.Encoder, except: [:password]}`, all fields except the
  specified ones would be encoded.

  ## Deriving outside of the module

      Protocol.derive(LiveReact.Encoder, User, only: [...])

  ## Custom implementations

      defimpl LiveReact.Encoder, for: User do
        def encode(struct, opts) do
          struct
          |> Map.take([:first, :second])
          |> LiveReact.Encoder.encode(opts)
        end
      end
  """

  @type t :: term
  @type opts :: Keyword.t()
  @fallback_to_any true

  @doc """
  Encodes a value to one of the primitive types.
  """
  @spec encode(t, opts) :: any()
  def encode(value, opts \\ [])
end

defimpl LiveReact.Encoder, for: Integer do
  def encode(value, _opts), do: value
end

defimpl LiveReact.Encoder, for: Float do
  def encode(value, _opts), do: value
end

defimpl LiveReact.Encoder, for: BitString do
  def encode(value, _opts), do: value
end

defimpl LiveReact.Encoder, for: Atom do
  def encode(atom, _opts), do: atom
end

defimpl LiveReact.Encoder, for: List do
  def encode(list, opts) do
    Enum.map(list, &LiveReact.Encoder.encode(&1, opts))
  end
end

defimpl LiveReact.Encoder, for: Map do
  def encode(map, opts) do
    Map.new(map, fn {key, value} ->
      {key, LiveReact.Encoder.encode(value, opts)}
    end)
  end
end

defimpl LiveReact.Encoder, for: [Date, Time, NaiveDateTime, DateTime] do
  def encode(value, _opts) do
    @for.to_iso8601(value)
  end
end

defimpl LiveReact.Encoder, for: Any do
  defmacro __deriving__(module, struct, opts) do
    fields = fields_to_encode(struct, opts)

    quote do
      defimpl LiveReact.Encoder, for: unquote(module) do
        def encode(struct, opts) do
          struct
          |> Map.take(unquote(fields))
          |> LiveReact.Encoder.encode(opts)
        end
      end
    end
  end

  def encode(%{__struct__: module} = struct, _opts) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: """
      LiveReact.Encoder protocol must always be explicitly implemented.

      It's used to encode structs to JSON for LiveReact. It's very similar to Jason.Encoder,
      but it's converting structs to maps so LiveReact can diff them correctly.

      If you own the struct, you can derive the implementation specifying \
      which fields should be encoded:

          defmodule #{inspect(module)} do
            @derive {LiveReact.Encoder, only: [...]}
            defstruct ...
          end

      If you don't own the struct you want to encode, \
      you may use Protocol.derive/3 placed outside of any module:

          Protocol.derive(LiveReact.Encoder, #{inspect(module)}, only: [...])
          Protocol.derive(LiveReact.Encoder, #{inspect(module)})

      Nothing prevents you from defining your own implementation for the struct:

      defimpl LiveReact.Encoder, for: #{inspect(module)} do
        def encode(struct, opts) do
          struct
          |> Map.take([:first, :second])
          |> LiveReact.Encoder.encode(opts)
        end
      end
      """
  end

  def encode(value, _opts), do: value

  defp fields_to_encode(struct, opts) do
    fields = Map.keys(struct)

    cond do
      only = Keyword.get(opts, :only) ->
        case only -- fields do
          [] ->
            only

          error_keys ->
            raise ArgumentError,
                  ":only specified keys (#{inspect(error_keys)}) that are not defined in defstruct: " <>
                    "#{inspect(fields -- [:__struct__])}"
        end

      except = Keyword.get(opts, :except) ->
        case except -- fields do
          [] ->
            fields -- [:__struct__ | except]

          error_keys ->
            raise ArgumentError,
                  ":except specified keys (#{inspect(error_keys)}) that are not defined in defstruct: " <>
                    "#{inspect(fields -- [:__struct__])}"
        end

      true ->
        fields -- [:__struct__]
    end
  end
end

defimpl LiveReact.Encoder, for: Phoenix.LiveView.AsyncResult do
  def encode(%Phoenix.LiveView.AsyncResult{} = struct, opts) do
    LiveReact.Encoder.encode(
      %{
        ok: struct.ok?,
        loading: struct.loading,
        failed: encode_failed(struct.failed),
        result: struct.result
      },
      opts
    )
  end

  defp encode_failed({:error, reason}), do: reason
  defp encode_failed({:exit, reason}), do: reason
  defp encode_failed(other), do: other
end

defimpl LiveReact.Encoder, for: Phoenix.LiveView.UploadConfig do
  def encode(%Phoenix.LiveView.UploadConfig{} = struct, opts) do
    errors =
      Enum.map(struct.errors, fn {key, value} ->
        %{ref: key, error: LiveReact.Encoder.encode(value, opts)}
      end)

    entries =
      Enum.map(struct.entries, fn entry ->
        encoded = LiveReact.Encoder.encode(entry, opts)
        entry_errors = errors |> Enum.filter(&(&1.ref == entry.ref)) |> Enum.map(& &1.error)
        Map.put(encoded, :errors, entry_errors)
      end)

    LiveReact.Encoder.encode(
      %{
        ref: struct.ref,
        name: struct.name,
        accept: struct.accept,
        max_entries: struct.max_entries,
        auto_upload: struct.auto_upload?,
        entries: entries,
        errors: errors
      },
      opts
    )
  end
end

defimpl LiveReact.Encoder, for: Phoenix.LiveView.UploadEntry do
  def encode(%Phoenix.LiveView.UploadEntry{} = struct, opts) do
    LiveReact.Encoder.encode(
      %{
        ref: struct.ref,
        client_name: struct.client_name,
        client_size: struct.client_size,
        client_type: struct.client_type,
        progress: struct.progress,
        done: struct.done?,
        valid: struct.valid?,
        preflighted: struct.preflighted?
      },
      opts
    )
  end
end

defimpl LiveReact.Encoder, for: Phoenix.HTML.Form do
  def encode(%Phoenix.HTML.Form{} = form, opts) do
    LiveReact.Encoder.encode(
      %{
        name: form.name,
        values: encode_form_values(form, opts),
        errors: encode_form_errors(form) || %{},
        valid: get_form_validity(form)
      },
      opts
    )
  end

  defp get_form_validity(%{source: %{valid?: valid}}), do: valid
  defp get_form_validity(_), do: true

  if Code.ensure_loaded?(Ecto) do
    @relations [:embed, :assoc]

    defp collect_changeset_values(%Ecto.Changeset{} = source, opts) do
      data =
        Map.new(source.types, fn {field, type} ->
          {field, get_field_value(source, field, type, opts)}
        end)

      result = if is_struct(source.data), do: Map.merge(source.data, data), else: data
      Map.delete(result, :__meta__)
    end

    defp get_field_value(source, field, {tag, %{cardinality: :one}}, opts)
         when tag in @relations do
      case Map.fetch(source.changes, field) do
        {:ok, nil} ->
          nil

        {:ok, %Ecto.Changeset{} = changeset} ->
          collect_changeset_values(changeset, opts)

        :error ->
          case Map.fetch!(source.data, field) do
            %Ecto.Association.NotLoaded{} = not_loaded ->
              if opts[:nilify_not_loaded], do: nil, else: not_loaded

            %{__meta__: _} = value ->
              Map.delete(value, :__meta__)

            value ->
              value
          end
      end
    end

    defp get_field_value(source, field, {tag, %{cardinality: :many}}, opts)
         when tag in @relations do
      case Map.fetch(source.changes, field) do
        {:ok, changesets} ->
          changesets
          |> Enum.filter(&(&1.params != nil))
          |> Enum.map(&collect_changeset_values(&1, opts))

        :error ->
          case Map.fetch!(source.data, field) do
            %Ecto.Association.NotLoaded{} = not_loaded ->
              if opts[:nilify_not_loaded], do: nil, else: not_loaded

            [%{__meta__: _} | _] = value ->
              Enum.map(value, &Map.delete(&1, :__meta__))

            value ->
              value
          end
      end
    end

    defp get_field_value(source, field, _type, _opts) do
      Phoenix.HTML.FormData.Ecto.Changeset.input_value(source, %{params: source.params}, field)
    end

    def encode_form_values(%{impl: Phoenix.HTML.FormData.Ecto.Changeset, source: source}, opts) do
      source |> collect_changeset_values(opts) |> LiveReact.Encoder.encode(opts)
    end
  end

  def encode_form_values(form, opts) do
    base_values =
      form.hidden
      |> Map.new()
      |> Map.merge(form.data)
      |> Map.merge(Map.new(form.params))

    LiveReact.Encoder.encode(base_values, opts)
  end

  if Code.ensure_loaded?(Ecto) do
    defp collect_changeset_errors(%Ecto.Changeset{} = changeset) do
      errors = translate_errors(changeset.errors)

      Enum.reduce(changeset.changes, errors, fn {field, value}, acc ->
        case Map.get(changeset.types, field) do
          {tag, %{cardinality: :one}} when tag in @relations ->
            embed_errors = collect_changeset_errors(value)
            if embed_errors == %{}, do: acc, else: Map.put(acc, field, embed_errors)

          {tag, %{cardinality: :many}} when tag in @relations ->
            list_errors =
              value
              |> Enum.filter(&(&1.params != nil))
              |> Enum.map(fn embed_changeset ->
                embed_errors = collect_changeset_errors(embed_changeset)
                if embed_errors == %{}, do: nil, else: embed_errors
              end)

            if Enum.all?(list_errors, &is_nil/1), do: acc, else: Map.put(acc, field, list_errors)

          _ ->
            acc
        end
      end)
    end

    def encode_form_errors(%{impl: Phoenix.HTML.FormData.Ecto.Changeset} = form) do
      collect_changeset_errors(form.source)
    end
  end

  def encode_form_errors(form) do
    translate_errors(form.errors)
  end

  defp translate_errors(errors) do
    Map.new(errors, fn {field, error} ->
      {field, error |> List.wrap() |> Enum.map(&translate_error/1)}
    end)
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(
        acc,
        "%{#{key}}",
        value
        |> List.wrap()
        |> Enum.map_join(", ", fn
          v when is_binary(v) or is_atom(v) or is_number(v) -> to_string(v)
          v -> inspect(v)
        end)
      )
    end)
  end
end
