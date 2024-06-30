defmodule LiveReact.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :live_react,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "E2E reactivity for React and LiveView",
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.2"},
      {:phoenix, ">= 1.7.0"},
      {:phoenix_html, ">= 3.3.1"},
      {:phoenix_live_view, ">= 0.18.0"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Baptiste Chaleil"],
      licenses: ["MIT"],
      links: %{
        Github: "https://github.com/mrdotb/live_react"
      }
    ]
  end

  defp docs do
    [
      name: "LiveReact",
      source_ref: "v#{@version}",
      source_url: "https://github.com/mrdotb/live_react",
      homepage_url: "https://github.com/mrdotb/live_react",
      main: "readme",
      extras: ["README.md"]
    ]
  end
end
