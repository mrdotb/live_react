defmodule LiveReact.Encoder.LiveViewTest do
  use ExUnit.Case

  alias LiveReact.Encoder
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.UploadConfig

  describe "AsyncResult" do
    test "encodes loading state" do
      result = AsyncResult.loading()
      encoded = Encoder.encode(result)

      assert encoded.ok == false
      assert encoded.loading == true
      assert encoded.result == nil
    end

    test "encodes successful state" do
      result = AsyncResult.loading() |> AsyncResult.ok("value")
      encoded = Encoder.encode(result)

      assert encoded.ok == true
      assert encoded.result == "value"
    end

    test "encodes failed state" do
      result = AsyncResult.loading() |> AsyncResult.failed({:error, "boom"})
      encoded = Encoder.encode(result)

      assert encoded.ok == false
      assert encoded.failed == "boom"
    end
  end

  describe "UploadEntry / UploadConfig" do
    test "encodes an empty UploadConfig" do
      config = UploadConfig.build(:avatar, "ref123", accept: :any, max_entries: 1)
      encoded = Encoder.encode(config)

      assert encoded.ref
      assert encoded.name == :avatar
      assert encoded.entries == []
      assert encoded.errors == []
    end
  end
end
