defmodule LiveReactExamplesWeb.Router do
  use LiveReactExamplesWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LiveReactExamplesWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # pipeline :api do
  #   plug :accepts, ["json"]
  # end

  scope "/", LiveReactExamplesWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/lazy", PageController, :lazy
    get "/simple", PageController, :simple
    get "/simple-props", PageController, :simple_props
    get "/typescript", PageController, :typescript

    live "/live-counter", LiveCounter
    live "/log-list", LiveLogList
    live "/flash-sonner", LiveFlashSonner
    live "/ssr", LiveSSR
    live "/hybrid-form", LiveHybridForm
  end

  # Other scopes may use custom stacks.
  # scope "/api", LiveReactExamplesWeb do
  #   pipe_through :api
  # end
end
