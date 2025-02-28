# Protobuf.Generate

![CI](https://github.com/drowzy/protobuf_generate/actions/workflows/ci.yml/badge.svg)
[![Hex.pm Version](https://img.shields.io/hexpm/v/protobuf_generate.svg?style=flat-square)](https://hex.pm/packages/protobuf_generate)

`protobuf.generate` is a mix task that allows you to generate Elixir code using [Protobuf](https://github.com/elixir-protobuf/protobuf) without using the `protoc-gen-elixir` plugin.

The generator calls `protoc` using `descriptor_set_out` to output a `FileDescriptorSet` into a temporary file for input to [Protobuf](https://github.com/elixir-protobuf/protobuf).

The difference between `protobuf.generate` and `protoc-gen-elixir` is that `protoc-gen-elixir` is called as a plugin to `protoc` and therefor executes in a
_global_ context while `protobuf.generate` executes in the context of the _local_ project. 

By executing in the context of the local project:

* Extensions that needs to be populated during code generation are picked up automatically by `Protobuf.load_extensions/0` (which is not possible when using `protoc-gen-elixir`).

* Integration into the codegen by using generator plugins. See `ProtobufGenerate.Plugin`

## Prerequisites

* [Protoc](https://github.com/protocolbuffers/protobuf#protocol-compiler-installation) (protocol buffer compiler) is required to be installed. [Download and install](https://grpc.io/docs/protoc-installation/) the protocol buffer compiler (protoc).

## Installation

This package can be installed by adding `protobuf_generate` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:protobuf_generate, "~> 0.1.0"}
  ]
end
```

## Usage

`mix protobuf.generate` supports the same options as [`protoc-gen-elixir`](https://github.com/elixir-protobuf/protobuf#generate-elixir-code)

### Arguments

  * `file` - One or more `.proto` files to compile

### Required options

  * `--output-path` - Path to output directory

### Optional options

  * `--include-path` - Specify the directory in which to search for imports. Eqvivalent to `protoc` `-I` flag.

  * `--tranform-module` - Module to do custom encoding/decoding for messages. See `Protobuf.TransformModule` for details.

  * `--package-prefix` - Prefix generated Elixir modules. For example prefix modules with: `MyApp.Protos` use `--package-prefix=my_app.protos`.

  * `--generate-descriptors` - Includes raw descriptors in the generated modules

  * `--one-file-per-module` - Changes the way files are generated into directories. This option creates a file for each generated Elixir module.

  * `--include-documentation` - Controls visibility of documentation of the generated modules. Setting `true` will not  have `@moduleoc false`

  * `--plugins=` - Generator plugins. If you write services in protobuf, you can generate gRPC code by passing `--plugin=ProtobufGenerate.Plugins.GRPC`.


```shell
$ mix protobuf.generate --output-path=./lib --include-path=./priv/protos helloworld.proto
$ mix protobuf.generate \
  --include-path=priv/proto \
  --include-path=deps/googleapis \
  --generate-descriptors=true \
  --output-path=./lib \
  --plugin=ProtobufGenerate.Plugins.GRPCWithOptions \
  google/api/annotations.proto google/api/http.proto helloworld.proto
```

## Available plugins

* `ProtobufGenerate.Plugins.GRPC` - Generate [gRPC](https://github.com/elixir-grpc/grpc) services
* `ProtobufGenerate.Plugins.GRPCWithOptions` -  Generate [gRPC](https://github.com/elixir-grpc/grpc) services with method extension options.

## Extensions

Extensions in the current project are loaded automatically when running `mix protobuf.generate`. However they need to be already generated in order for `Protobuf.load_extensions/0` to pick them up.

## Acknowledgements

* [`protox`](https://github.com/ahamez/protox) for running `protoc` with `descriptor_set_out`
