defmodule LiveReact.EncoderFormTest do
  use ExUnit.Case

  import Ecto.Changeset
  import Phoenix.Component, only: [to_form: 2]

  alias LiveReact.Encoder
  alias Phoenix.HTML.FormData

  defp encode_form(source, attrs) do
    module = source.__struct__
    changeset = module.changeset(source, attrs)
    form = FormData.to_form(changeset, as: module.__schema__(:source))
    Encoder.encode(form)
  end

  defmodule Simple do
    @moduledoc false
    use Ecto.Schema

    import Ecto.Changeset

    @derive {Encoder, except: [:secret]}
    embedded_schema do
      field(:name, :string)
      field(:secret, :string)
      field(:age, :integer)
      field(:active, :boolean)
      field(:tags, {:array, :string})
      field(:score, :float)
    end

    def changeset(simple, attrs) do
      simple
      |> cast(attrs, [:name, :secret, :age, :active, :tags, :score])
      |> validate_required([:name])
      |> validate_number(:age, greater_than: 0)
      |> validate_number(:score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    end
  end

  describe "Phoenix.HTML.Form encoding — Ecto changeset backed" do
    test "encodes form with simple values" do
      simple = %Simple{}

      attrs = %{
        name: "John",
        secret: "hidden_value",
        age: 30,
        active: true,
        tags: ["elixir", "phoenix"],
        score: 95.5
      }

      encoded = encode_form(simple, attrs)

      assert encoded == %{
               name: "simple",
               values: %{
                 id: nil,
                 name: "John",
                 age: 30,
                 active: true,
                 tags: ["elixir", "phoenix"],
                 score: 95.5
               },
               errors: %{},
               valid: true
             }
    end

    test "encodes form with validation errors" do
      simple = %Simple{}
      attrs = %{name: nil, age: -5, score: 150}
      encoded = encode_form(simple, attrs)

      assert encoded.name == "simple"
      assert encoded.valid == false

      assert encoded.values == %{
               id: nil,
               name: nil,
               age: -5,
               active: nil,
               tags: nil,
               score: 150
             }

      assert encoded.errors == %{
               name: ["can't be blank"],
               age: ["must be greater than 0"],
               score: ["must be less than or equal to 100"]
             }
    end
  end

  describe "Phoenix.HTML.Form encoding — plain map backed (no Ecto)" do
    test "encodes form backed by simple map data" do
      form_data = %{
        "name" => "John Doe",
        "email" => "john@example.com",
        "role" => "developer",
        "bio" => "Software engineer with 5 years experience",
        "notifications" => true
      }

      form = to_form(form_data, as: :user)
      encoded = Encoder.encode(form)

      assert encoded == %{
               name: "user",
               values: %{
                 "name" => "John Doe",
                 "email" => "john@example.com",
                 "role" => "developer",
                 "bio" => "Software engineer with 5 years experience",
                 "notifications" => true
               },
               errors: %{},
               valid: true
             }
    end

    test "encodes form with empty map data" do
      form_data = %{
        "name" => "",
        "email" => "",
        "role" => "",
        "bio" => "",
        "notifications" => false
      }

      form = to_form(form_data, as: :profile)
      encoded = Encoder.encode(form)

      assert encoded == %{
               name: "profile",
               values: %{
                 "name" => "",
                 "email" => "",
                 "role" => "",
                 "bio" => "",
                 "notifications" => false
               },
               errors: %{},
               valid: true
             }
    end
  end
end
