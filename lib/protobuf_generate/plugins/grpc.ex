defmodule ProtobufGenerate.Plugins.GRPC do
  # ref: https://github.com/elixir-protobuf/protobuf/blob/main/lib/protobuf/protoc/generator/grpc.ex
  @moduledoc """
  Plugin to Generate gRPC code from protbuf service definitions
  """

  @behaviour ProtobufGenerate.Plugin

  alias Protobuf.Protoc.Generator.Util

  @impl true
  def template do
    """
    defmodule <%= @module %>.Service do
      @moduledoc false
      use GRPC.Service, name: <%= inspect(@service_name) %>, protoc_gen_elixir_version: "<%= @version %>"

      <%= if @descriptor_fun_body do %>
       def descriptor do
         # credo:disable-for-next-line
         <%= @descriptor_fun_body %>
       end
      <% end %>

     <%= for {method_name, input, output} <- @methods do %>
       rpc :<%= method_name %>, <%= input %>, <%= output %>
     <% end %>
    end
    """
  end

  @impl true
  def generate(ctx, %Google.Protobuf.FileDescriptorProto{service: svcs} = desc) do
    for svc <- svcs do
      mod_name = Util.mod_name(ctx, [Macro.camelize(svc.name)])
      name = Util.prepend_package_prefix(ctx.package, svc.name)

      descriptor_fun_body =
        if ctx.gen_descriptors? do
          Util.descriptor_fun_body(desc)
        else
          nil
        end

      methods =
        for m <- svc.method do
          input = service_arg(Util.type_from_type_name(ctx, m.input_type), m.client_streaming)

          output = service_arg(Util.type_from_type_name(ctx, m.output_type), m.server_streaming)

          {m.name, input, output}
        end

      {mod_name,
       [
         module: mod_name,
         service_name: name,
         methods: methods,
         descriptor_fun_body: descriptor_fun_body,
         version: Util.version()
       ]}
    end
  end

  defp service_arg(type, _streaming? = true), do: "stream(#{type})"
  defp service_arg(type, _streaming?), do: type
end
