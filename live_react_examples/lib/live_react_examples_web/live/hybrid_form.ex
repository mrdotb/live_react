defmodule LiveReactExamplesWeb.LiveHybridForm do
  use LiveReactExamplesWeb, :live_view

  def render(assigns) do
    ~H"""
    <h1 class="flex justify-center mb-10 font-bold">Hybrid form</h1>

    <.simple_form for={@form} phx-change="validate" phx-submit="submit">
      <.input field={@form[:email]} label="Email" />
      <.react
        label="Delay Between"
        name="DelaySlider"
        inputName="settings[delay_between]"
        value={@form[:delay_between].value}
        min={2_000}
        max={90_000}
        step={2_000}
      />
    </.simple_form>

    <div class="mt-10">
      <pre>
        <%= inspect(@form.params, pretty: true) %>
      </pre>
    </div>
    """
  end

  def mount(_session, _params, socket) do
    form =
      to_form(
        %{
          "email" => "hello@mrdotb.com",
          "delay_between" => [4_000, 30_000]
        },
        as: :settings
      )

    socket = assign(socket, form: form)
    {:ok, socket}
  end

  def handle_event("validate", %{"settings" => settings}, socket) do
    form = to_form(settings, as: :settings, action: :validate)
    socket = assign(socket, form: form)
    {:noreply, socket}
  end

  def handle_event("submit", _, socket) do
    {:noreply, socket}
  end
end
