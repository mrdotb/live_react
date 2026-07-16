defmodule LiveReact.EncoderTest do
  use ExUnit.Case

  alias LiveReact.Encoder

  describe "primitive types" do
    test "encodes integers, floats, strings, booleans, nil, atoms" do
      assert Encoder.encode(42) == 42
      assert Encoder.encode(3.14) == 3.14
      assert Encoder.encode("hello") == "hello"
      assert Encoder.encode(true) == true
      assert Encoder.encode(false) == false
      assert Encoder.encode(nil) == nil
      assert Encoder.encode(:hello) == :hello
    end
  end

  describe "complex types" do
    test "encodes lists recursively" do
      assert Encoder.encode([1, [2, 3], 4]) == [1, [2, 3], 4]
      assert Encoder.encode([]) == []
    end

    test "encodes maps recursively" do
      nested = %{user: %{name: "John", age: 30}, items: [1, 2, 3]}
      assert Encoder.encode(nested) == nested
    end
  end

  defmodule TestUser do
    @moduledoc false
    @derive Encoder
    defstruct [:name, :age, :email]
  end

  defmodule TestAccount do
    @moduledoc false
    @derive Encoder
    defstruct [:user, :balance]
  end

  defmodule DerivedUserOnly do
    @moduledoc false
    @derive {Encoder, only: [:name, :age]}
    defstruct [:name, :age, :email, :password]
  end

  defmodule DerivedUserExcept do
    @moduledoc false
    @derive {Encoder, except: [:password]}
    defstruct [:name, :age, :email, :password]
  end

  defmodule NotDerivedUser do
    @moduledoc false
    defstruct [:name, :age, :email]
  end

  describe "structs" do
    test "encodes structs to maps without __struct__" do
      user = %TestUser{name: "John", age: 30, email: "john@example.com"}
      encoded = Encoder.encode(user)

      assert encoded == %{name: "John", age: 30, email: "john@example.com"}
      refute Map.has_key?(encoded, :__struct__)
    end

    test "encodes nested structs" do
      account = %TestAccount{
        user: %TestUser{name: "John", age: 30, email: "j@x.com"},
        balance: 1000
      }

      assert Encoder.encode(account) == %{
               user: %{name: "John", age: 30, email: "j@x.com"},
               balance: 1000
             }
    end

    test "encodes structs in lists and maps" do
      users = [%TestUser{name: "John", age: 30, email: "j@x.com"}]
      assert Encoder.encode(users) == [%{name: "John", age: 30, email: "j@x.com"}]

      assert Encoder.encode(%{admin: %TestUser{name: "Jane", age: 25, email: "ja@x.com"}}) ==
               %{admin: %{name: "Jane", age: 25, email: "ja@x.com"}}
    end
  end

  describe "deriving functionality" do
    test "derives encoder with only specified fields" do
      user = %DerivedUserOnly{name: "John", age: 30, email: "j@x.com", password: "secret"}
      assert Encoder.encode(user) == %{name: "John", age: 30}
    end

    test "derives encoder excluding specified fields" do
      user = %DerivedUserExcept{name: "John", age: 30, email: "j@x.com", password: "secret"}
      assert Encoder.encode(user) == %{name: "John", age: 30, email: "j@x.com"}
    end

    test "non-derived structs raise protocol error" do
      struct = %NotDerivedUser{name: "John", age: 30, email: "j@x.com"}

      assert_raise Protocol.UndefinedError,
                   ~r/LiveReact.Encoder protocol must always be explicitly implemented/,
                   fn ->
                     Encoder.encode(struct)
                   end
    end
  end

  describe "date and time types" do
    test "encodes date and time types as ISO8601 strings" do
      date = ~D[2023-01-01]
      naive_datetime = ~N[2023-01-01 12:00:00]
      datetime = DateTime.from_naive!(naive_datetime, "Etc/UTC")

      assert Encoder.encode(date) == Date.to_iso8601(date)
      assert Encoder.encode(naive_datetime) == NaiveDateTime.to_iso8601(naive_datetime)
      assert Encoder.encode(datetime) == DateTime.to_iso8601(datetime)
    end
  end
end
