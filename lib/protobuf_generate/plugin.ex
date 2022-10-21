defmodule ProtobufGenerate.Plugin do
  @type template_assigns :: {String.t(), keyword()}

  @type state ::
          template_assigns()
          | {atom(), template_assigns()}
          | [template_assigns() | {atom(), template_assigns()}]

  @callback template() :: String.t()
  @callback generate(Protobuf.Protoc.Context.t(), Google.Protobuf.FileDescriptorProto) :: state()
end
