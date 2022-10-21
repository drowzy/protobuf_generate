defmodule ProtobufGenerate.Plugins.Enum do
  @moduledoc false
  @behaviour ProtobufGenerate.Plugin

  alias Protobuf.Protoc.Context
  alias Protobuf.Protoc.Generator.Util

  @impl true
  def template(_) do
    """
    defmodule <%= @module %> do
      @moduledoc false
      use Protobuf, <%= @use_options %>

      <%= if @descriptor_fun_body do %>
      def descriptor do
        # credo:disable-for-next-line
        <%= @descriptor_fun_body %>
      end
      <% end %>

      <%= for %Google.Protobuf.EnumValueDescriptorProto{name: name, number: number} <- @fields do %>
      field :<%= name %>, <%= number %><% end %>
    end
    """
  end

  @impl true
  def generate(ctx, %Google.Protobuf.FileDescriptorProto{enum_type: enum_types}) do
    for type <- enum_types, do: generate(ctx, type)
  end

  def generate(%Context{namespace: ns} = ctx, %Google.Protobuf.EnumDescriptorProto{} = desc) do
    msg_name = Util.mod_name(ctx, ns ++ [Macro.camelize(desc.name)])

    use_options =
      Util.options_to_str(%{
        syntax: ctx.syntax,
        enum: true,
        protoc_gen_elixir_version: "\"#{Util.version()}\""
      })

    descriptor_fun_body =
      if ctx.gen_descriptors? do
        Util.descriptor_fun_body(desc)
      else
        nil
      end

    {msg_name,
     [
       module: msg_name,
       use_options: use_options,
       fields: desc.value,
       descriptor_fun_body: descriptor_fun_body
     ]}
  end
end
