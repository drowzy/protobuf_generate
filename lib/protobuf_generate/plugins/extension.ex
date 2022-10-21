defmodule ProtobufGenerate.Plugins.Extension do
  @moduledoc false

  @behaviour ProtobufGenerate.Plugin

  alias Protobuf.Protoc.Context
  alias Protobuf.Protoc.Generator.Util

  @ext_postfix "PbExtension"

  @impl true
  def template(_) do
    """
    defmodule <%= @module %> do
      @moduledoc false
      use Protobuf, <%= @use_options %>

      <%= for ext <- @extends do %>
      extend <%= ext %>
      <% end %>
    end
    """
  end

  @impl true
  def generate(%Context{namespace: ns} = ctx, %Google.Protobuf.FileDescriptorProto{} = desc) do
    nested_extensions = get_nested_extensions(ctx, desc.message_type)
    extends = Enum.map(desc.extension, &generate_extend(ctx, &1, _ns = ""))

    nested_extends =
      Enum.flat_map(nested_extensions, fn {ns, exts} ->
        ns = Enum.join(ns, ".")
        Enum.map(exts, &generate_extend(ctx, &1, ns))
      end)

    case extends ++ nested_extends do
      [] ->
        []

      extends ->
        msg_name = Util.mod_name(ctx, ns ++ [Macro.camelize(@ext_postfix)])

        use_options =
          Util.options_to_str(%{
            syntax: ctx.syntax,
            protoc_gen_elixir_version: "\"#{Util.version()}\""
          })

        {msg_name,
         [
           module: msg_name,
           use_options: use_options,
           extends: extends
         ]}
    end
  end

  defp generate_extend(ctx, f, ns) do
    extendee = Util.type_from_type_name(ctx, f.extendee)
    f = Protobuf.Protoc.Generator.Message.get_field(ctx, f)

    name =
      if ns == "" do
        f.name
      else
        inspect("#{ns}.#{f.name}")
      end

    "#{extendee}, :#{name}, #{f.number}, #{f.label}: true, type: #{f.type}#{f.opts_str}"
  end

  defp get_nested_extensions(%Context{} = ctx, descs) when is_list(descs) do
    get_nested_extensions(ctx.namespace, descs, _acc = [])
  end

  defp get_nested_extensions(_ns, _descs = [], acc) do
    Enum.reverse(acc)
  end

  defp get_nested_extensions(ns, descs, acc) do
    descs
    |> Enum.reject(&(&1.extension == []))
    |> Enum.reduce(acc, fn desc, acc ->
      new_ns = ns ++ [Macro.camelize(desc.name)]
      acc = [_extension = {new_ns, desc.extension} | acc]
      get_nested_extensions(new_ns, desc.nested_type, acc)
    end)
  end
end
