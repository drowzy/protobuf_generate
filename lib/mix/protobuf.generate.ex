defmodule Mix.Tasks.Protobuf.Generate do
  @moduledoc """
  Generate Elixir code from `.proto` files.


  ## Arguments

  * `FILE` - One or more `.proto` files to compile

  ## Required options

  * `--output-path` - Path to output directory

  ## Optional options

  * `--include-path` - Specify the directory in which to search for imports. Eqvivalent to `protoc` `-I` flag.
  * `--tranform-module` - Module to do custom encoding/decoding for messages. See `Protobuf.TransformModule` for details.
  * `--package-prefix` - Prefix generated Elixir modules. For example prefix modules with: `MyApp.Protos` use `--package-prefix=my_app.protos`.
  * `--generate-descriptors` - Includes raw descriptors in the generated modules
  * `--one-file-per-module` - Changes the way files are generated into directories. This option creates a file for each generated Elixir module.
  * `--include-documentation` - Controls visibility of documentation of the generated modules. Setting `true` will not  have `@moduleoc false`
  * `--plugins` - If you write services in protobuf, you can generate gRPC code by passing `--plugins=grpc`.

  ## Examples

      $ mix protobuf.generate --output-path=./lib --include-path=./priv/protos helloworld.proto

      $ mix protobuf.generate \
        --include-path=priv/proto \
        --include-path=deps/googleapis \
        --generate-descriptors=true \
        --output-path=./lib \
        google/api/annotations.proto google/api/http.proto helloworld.proto

  """
  @shortdoc "Generate Elixir code from Protobuf definitions"

  use Mix.Task

  alias ProtobufGenerate.{Protoc, CodeGen}
  alias Protobuf.Protoc.Context

  @switches [
    output_path: :string,
    include_path: :keep,
    generate_descriptors: :boolean,
    package_prefix: :string,
    transform_module: :string,
    include_docs: :boolean,
    one_file_per_module: :boolean,
    plugins: :keep
  ]

  @impl Mix.Task
  @spec run(any) :: any
  def run(args) do
    {opts, files} = OptionParser.parse!(args, strict: @switches)
    {plugins, opts} = pop_values(opts, :plugins)
    {imports, opts} = pop_values(opts, :include_path)

    transform_module =
      case Keyword.fetch(opts, :transform_module) do
        {:ok, t} -> Module.concat([t])
        :error -> nil
      end

    output_path =
      opts
      |> Keyword.fetch!(:output_path)
      |> Path.expand()

    Protobuf.load_extensions()

    case Protoc.run(files, imports) do
      {:ok, bin} ->
        ctx = %Context{
          gen_descriptors?: Keyword.get(opts, :generate_descriptors, false),
          plugins: plugins,
          transform_module: transform_module,
          package_prefix: Keyword.get(opts, :package_prefix)
          # include_docs?: Keyword.get(opts, :include_docs, false)
        }

        request = decode(files, imports, bin)
        response = generate(ctx, request)

        Enum.each(response.file, &generate_file(output_path, &1))

      {:error, reason} ->
        IO.puts(:stderr, "Failed to generate code: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp decode(files, imports, bin) do
    %Google.Protobuf.FileDescriptorSet{file: file_descriptors} =
      Protobuf.Decoder.decode(bin, Google.Protobuf.FileDescriptorSet)

    files = normalize_import_paths(files, imports, [])

    Google.Protobuf.Compiler.CodeGeneratorRequest.new(
      file_to_generate: files,
      proto_file: file_descriptors
    )
  end

  defp generate(ctx, request) do
    ctx = Protobuf.Protoc.CLI.find_types(ctx, request.proto_file, request.file_to_generate)

    plugins =
      [
        ProtobufGenerate.Plugins.Enum,
        ProtobufGenerate.Plugins.Extension,
        ProtobufGenerate.Plugins.Message
      ] ++ if "grpc" in ctx.plugins, do: [ProtobufGenerate.Plugins.GRPC], else: []

    files =
      Enum.flat_map(request.file_to_generate, fn file ->
        desc = Enum.find(request.proto_file, &(&1.name == file))
        CodeGen.generate(ctx, desc, plugins)
      end)

    response =
      Google.Protobuf.Compiler.CodeGeneratorResponse.new(
        file: files,
        supported_features: Protobuf.Protoc.CLI.supported_features()
      )

    response
  end

  defp generate_file(output_path, %{name: file_name, content: content}) do
    path = Path.join([output_path, file_name])
    dir = Path.dirname(path)

    File.mkdir_p!(dir)
    File.write!(path, content)
  end

  defp pop_values(opts, key) do
    {values, new_opts} =
      Enum.reduce(opts, {[], []}, fn
        {^key, value}, {values, new_opts} -> {[value | values], new_opts}
        {key, value}, {values, new_opts} -> {values, [{key, value} | new_opts]}
      end)

    {Enum.reverse(values), Enum.reverse(new_opts)}
  end

  defp normalize_import_paths(files, [], _), do: files
  defp normalize_import_paths([], _, acc), do: Enum.reverse(acc)

  defp normalize_import_paths([file | rest], imports, acc) do
    file_path =
      Enum.reduce_while(imports, file, fn i, file ->
        relative_path = Path.relative_to(file, i)

        if relative_path == file do
          {:cont, file}
        else
          {:halt, relative_path}
        end
      end)

    normalize_import_paths(rest, imports, [file_path | acc])
  end
end
