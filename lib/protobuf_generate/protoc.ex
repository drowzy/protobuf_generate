defmodule ProtobufGenerate.Protoc do
  @moduledoc false
  # https://github.com/ahamez/protox/blob/master/lib/protox/protoc.ex
  def run(_files = [proto_file], _imports = []),
    do: run_protoc([proto_file], ["-I", "#{proto_file |> Path.dirname() |> Path.expand()}"])

  def run([proto_file], paths),
    do: run_protoc([proto_file], paths_to_protoc_args(paths))

  def run(proto_files, []),
    do: run_protoc(proto_files, ["-I", "#{common_directory_path(proto_files)}"])

  def run(proto_files, paths),
    do: run_protoc(proto_files, paths_to_protoc_args(paths))

  defp run_protoc(proto_files, args) do
    outfile_name = "protobuf_#{random_string()}"
    outfile_path = Path.join([Mix.Project.build_path(), outfile_name])

    cmd_args =
      ["--include_imports", "--include_source_info", "-o", outfile_path] ++ args ++ proto_files

    try do
      System.cmd("protoc", cmd_args, stderr_to_stdout: true)
    catch
      :error, :enoent ->
        raise "protoc executable is missing. Please make sure Protocol Buffers " <>
                "is installed and available system wide"
    else
      {_, 0} ->
        file_content = File.read!(outfile_path)
        :ok = File.rm(outfile_path)
        {:ok, file_content}

      {msg, _} ->
        {:error, msg}
    end
  end

  defp paths_to_protoc_args(paths) do
    paths
    |> Enum.map(&["-I", &1])
    |> Enum.concat()
  end

  defp common_directory_path(paths_rel) do
    paths = Enum.map(paths_rel, &Path.expand/1)

    min_path = paths |> Enum.min() |> Path.split()
    max_path = paths |> Enum.max() |> Path.split()

    min_path
    |> Enum.zip(max_path)
    |> Enum.take_while(fn {a, b} -> a == b end)
    |> Enum.map(fn {x, _} -> x end)
    |> Path.join()
  end

  defp random_string(len \\ 16) do
    "#{Enum.take_random(?a..?z, len)}"
  end
end
