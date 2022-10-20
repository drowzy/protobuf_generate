# Protobuf.Generators

`proto_gen` is a mix task that allows you to call `protoc` without the need of a global installed plugin.


The difference between `protobuf.generate` and `protoc-gen-elixir` is that `protoc-gen-elixir` is called as a plugin to `protoc`. `protoc-gen-elixir` executes in a global context while `protobuf.generate` executes in the context of the _local_ project.

`proto_gen` uses `protoc` ability to output `FileDescriptorSet` into a temporary file which is then decoded using [Protobuf](https://github.com/elixir-protobuf/protobuf). It provides the same abilities as `protoc-gen-elixir` but instead of being called by `protoc`, `protobuf.generate` _calls_ `protoc` which allows for features such as extensions being properly loaded.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `proto_gen` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:protobuf_generate, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/proto_gen>.

## Features

* Extensions in the current project are picked up automatically by `Protobuf.load_extensions()` (or can be provided as an argument to `protobuf.generate`).

* Allows integration into the codegen by using generator plugins. See `lib/generators/grpc.ex`


## Protoc
[Protoc](https://github.com/protocolbuffers/protobuf#protocol-compiler-installation) (protocol buffer compiler) is required to be installed. [Download and install](https://grpc.io/docs/protoc-installation/) the protocol buffer compiler (protoc).

