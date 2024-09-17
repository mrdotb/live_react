defmodule LiveReact.SSR.NodeJS do
  @moduledoc """
  Implements SSR by using `NodeJS` package.

  Under the hood, it invokes "render" function exposed by `server.js` file.
  You can see how `server.js` is created by looking at `assets.deploy` command
  and `package.json` build-server script.
  """

  @behaviour LiveReact.SSR

  def render(name, props) do
    filename = Application.get_env(:live_react, :ssr_filepath, "./react/server.js")

    if Code.ensure_loaded?(NodeJS) do
      try do
        # Dynamically apply the NodeJS.call!/3 to avoid compiler warning
        apply(NodeJS, :call!, [{filename, "render"}, [name, props], [binary: true, esm: true]])
      catch
        :exit, {:noproc, _} ->
          message = """
          NodeJS is not configured. Please add the following to your application.ex:
          {NodeJS.Supervisor, [path: LiveReact.SSR.NodeJS.server_path(), pool_size: 4]},
          """

          raise %LiveReact.SSR.NotConfigured{message: message}
      end
    else
      message = """
      NodeJS is not installed. Please add the following to mix.ex deps:
      `{:nodejs, "~> 3.1"}`
      """

      raise %LiveReact.SSR.NotConfigured{message: message}
    end
  end

  def server_path() do
    {:ok, path} = :application.get_application()
    Application.app_dir(path, "/priv")
  end
end
