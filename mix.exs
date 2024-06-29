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
      package: package()
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
      {:esbuild, "~> 0.5", only: :dev},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  def package do
    [
      maintainers: ["Baptiste Chaleil"],
      licenses: ["MIT"],
      links: %{
        Changelog: "",
        Github: "https://github.com/mrdotb/live_react"
      }
    ]
  end
end
