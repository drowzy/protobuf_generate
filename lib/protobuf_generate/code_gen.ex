defmodule ProtobufGenerate.CodeGen do
  @moduledoc false
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

    module_definitions
    |> List.flatten()
    |> generate_files(desc, ctx.one_file_per_module?)
  end

  def eval(msgs, template) when is_list(msgs) do
    for msg <- msgs, do: eval(msg, template)
  end

  def eval({mod_name, assigns}, template) when is_binary(mod_name) do
    content =
      template
      |> EEx.eval_string(assigns: assigns)
      |> Util.format()

    {mod_name, content}
  end

  def eval({plugin, {_mod_name, _assigns} = msg}, _template) when is_atom(plugin) do
    unless function_exported?(plugin, :template, 0) do
      raise "#{inspect(plugin)} does not implement the `template/0` callback"
    end

    eval(msg, plugin.template(%{}))
  end

  defp generate_files(module_definitions, _desc, _file_per_module = true) do
    for {mod_name, content} <- module_definitions do
      file_name = Macro.underscore(mod_name) <> ".pb.ex"

      Google.Protobuf.Compiler.CodeGeneratorResponse.File.new(
        name: file_name,
        content: content
      )
    end
  end

  defp generate_files(module_definitions, desc, _file_per_module = false) do
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

  defp get_dep_type_mapping(%{global_type_mapping: global_mapping}, deps, file_name) do
    mapping =
      Enum.reduce(deps, %{}, fn dep, acc ->
        Map.merge(acc, global_mapping[dep])
      end)

    Map.merge(mapping, global_mapping[file_name])
  end

  defp syntax("proto3"), do: :proto3
  defp syntax(_), do: :proto2
end
