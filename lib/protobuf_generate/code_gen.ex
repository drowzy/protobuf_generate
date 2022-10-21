defmodule ProtobufGenerate.CodeGen do
  require EEx

  alias Protobuf.Protoc.Context
  alias Protobuf.Protoc.Generator.Util

  def generate(%Context{} = ctx, %Google.Protobuf.FileDescriptorProto{} = desc, plugins) do
    ctx =
      %Context{
        ctx
        | syntax: syntax(desc.syntax),
          package: desc.package,
          dep_type_mapping: get_dep_type_mapping(ctx, desc.dependency, desc.name)
      }
      |> Protobuf.Protoc.Context.custom_file_options_from_file_desc(desc)

    module_definitions =
      for plugin <- plugins do
        template = plugin.template()

        ctx
        |> plugin.generate(desc)
        |> eval(template)
      end

    module_definitions = List.flatten(module_definitions)

    if ctx.one_file_per_module? do
      for {mod_name, content} <- module_definitions do
        file_name = Macro.underscore(mod_name) <> ".pb.ex"

        Google.Protobuf.Compiler.CodeGeneratorResponse.File.new(
          name: file_name,
          content: content
        )
      end
    else
      # desc.name is the filename, ending in ".proto".
      file_name = Path.rootname(desc.name) <> ".pb.ex"

      content =
        module_definitions
        |> Enum.map(fn {_mod_name, contents} -> [contents, ?\n] end)
        |> IO.iodata_to_binary()
        |> Util.format()

      [
        Google.Protobuf.Compiler.CodeGeneratorResponse.File.new(
          name: file_name,
          content: content
        )
      ]
    end
  end

  @spec eval([{String.t(), keyword() | {atom(), {String.t(), keyword()}}}], binary()) ::
          [{binary(), binary()}] | {binary(), binary()}
  def eval(msgs, template) when is_list(msgs) do
    for msg <- msgs, do: eval(msg, template)
  end

  def eval({mod_name, assigns}, template) when is_binary(mod_name) do
    {mod_name, EEx.eval_string(template, assigns: assigns)}
  end

  def eval({plugin, {_mod_name, _assigns} = msg}, _template) when is_atom(plugin) do
    unless function_exported?(plugin, :template, 1) do
      raise "#{inspect(plugin)} does not implement the `implement/1` callback"
    end

    eval(msg, plugin.template(%{}))
  end

  defp get_dep_type_mapping(%Context{global_type_mapping: global_mapping}, deps, file_name) do
    mapping =
      Enum.reduce(deps, %{}, fn dep, acc ->
        Map.merge(acc, global_mapping[dep])
      end)

    Map.merge(mapping, global_mapping[file_name])
  end

  defp syntax("proto3"), do: :proto3
  defp syntax("proto2"), do: :proto2
  defp syntax(nil), do: :proto2
end
