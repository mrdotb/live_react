defmodule LiveReactExamplesWeb.ErrorJSONTest do
  use LiveReactExamplesWeb.ConnCase, async: true

  test "renders 404" do
    assert LiveReactExamplesWeb.ErrorJSON.render("404.json", %{}) == %{
             errors: %{detail: "Not Found"}
           }
  end

  test "renders 500" do
    assert LiveReactExamplesWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
