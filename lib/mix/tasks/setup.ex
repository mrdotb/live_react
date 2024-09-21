defmodule Mix.Tasks.LiveReact.Setup do
  @moduledoc """
  Copies files from assets/copy of the live_react dependency to phoenix project assets folder
  """
  @shortdoc "copy setup files to assets"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Project.deps_paths(depth: 1)
    |> Map.fetch!(:live_react)
    |> Path.join("assets/copy/**/{*.*}")
    |> Path.wildcard(match_dot: true)
    |> Enum.each(fn full_path ->
      [_beginning, relative_path] = String.split(full_path, "copy", parts: 2)
      new_path = "assets" <> relative_path

      case File.exists?(new_path) do
        true ->
          log_info(~s/Did not copy `#{full_path}` to `#{new_path}` since file already exists/)

        false ->
          Mix.Generator.copy_file(full_path, new_path)
      end
    end)
  end

  defp log_info(status), do: Mix.shell().info([status, :reset])
end
