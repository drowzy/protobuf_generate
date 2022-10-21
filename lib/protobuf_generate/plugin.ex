defmodule ProtobufGenerate.Plugin do
  @moduledoc ~s"""
  Plugins are modules which can used to hook in to code generation.

  A plugin is a module that provides `c:template/0` and a `c:generate/2` callbacks.

    defmodule GeneratePlugin do
      @behaviour ProtobufGenerate.Plugin
      alias Protobuf.Protoc.Generator.Util

      def template do
        \"""
        defmodule <%= @module %> do
          def descriptor do
            <%= @descriptor_body %>
          end
        end
        \"""
      end

      def generate(ctx, %Google.Protobuf.FileDescriptorProto{} = desc) do
        mod_name = Util.mod_name(ctx, desc.name)
        descriptor_body = Util.descriptor_fun_body(desc)

        {mod_name, module: mod_name, descriptor_body: descriptor_body}
      end
    end

  As an example the `ProtobufGenerate.Plugin.GRPCWithOptions` plugin is implemented as:


    defmodule ProtobufGenerate.Plugins.GRPCWithOptions do
      @behaviour ProtobufGenerate.Plugin

      alias Protobuf.Protoc.Generator.Util

      @impl true
      def template do
        \"""
        defmodule <%= @module %>.Service do
          @moduledoc false
          use GRPC.Service, name: <%= inspect(@service_name) %>, protoc_gen_elixir_version: "<%= @version %>"

          <%= if @descriptor_fun_body do %>
           def descriptor do
             # credo:disable-for-next-line
             <%= @descriptor_fun_body %>
           end
          <% end %>

         <%= for {method_name, input, output, options} <- @methods do %>
           rpc :<%= method_name %>, <%= input %>, <%= output %>, <%= options %>
         <% end %>
        end
        \"""
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

              options =
                m.options
                |> opts()
                |> inspect(limit: :infinity)

              {m.name, input, output, options}
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

      defp service_arg(type, _streaming? = true), do: "stream(\#{type})"
      defp service_arg(type, _streaming?), do: type

      defp opts(%Google.Protobuf.MethodOptions{__pb_extensions__: extensions})
           when extensions == %{} do
        %{}
      end

      defp opts(%Google.Protobuf.MethodOptions{__pb_extensions__: extensions}) do
        for {{type, field}, value} <- extensions, into: %{} do
          {field, %{type: type, value: value}}
        end
      end
    end


  The `ProtobufGenerate.Plugin` module provides a number of functions to make implementing generators easier.

  **TODO**
  """

  @type template_assigns :: {String.t(), keyword()}

  @type state ::
          template_assigns()
          | {atom(), template_assigns()}
          | [template_assigns() | {atom(), template_assigns()}]

  @callback template() :: String.t()
  @callback generate(Protobuf.Protoc.Context.t(), Google.Protobuf.FileDescriptorProto) :: state()
end
