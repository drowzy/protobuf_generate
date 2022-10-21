# Protobuf.Generate

`protobuf_generate` is a mix task that allows you to call `protoc` without the need of a global installed plugin.


The difference between `protobuf.generate` and `protoc-gen-elixir` is that `protoc-gen-elixir` is called as a plugin to `protoc`. `protoc-gen-elixir` executes in a global context while `protobuf.generate` executes in the context of the _local_ project.

`proto_gen` uses `protoc` ability to output `FileDescriptorSet` into a temporary file which is then decoded using [Protobuf](https://github.com/elixir-protobuf/protobuf). It provides the same abilities as `protoc-gen-elixir` but instead of being called by `protoc`, `protobuf.generate` _calls_ `protoc` which allows for features such as extensions being properly loaded.

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
  * `--plugins` - If you write services in protobuf, you can generate gRPC code by passing `--plugins=grpc`.


```shell
$ mix protobuf.generate --output-path=./lib --include-path=./priv/protos helloworld.proto
$ mix protobuf.generate \
  --include-path=priv/proto \
  --include-path=deps/googleapis \
  --generate-descriptors=true \
  --output-path=./lib \
  --plugins=ProtobufGenerate.Plugins.GRPCWithOptions \
  google/api/annotations.proto google/api/http.proto helloworld.proto
```

## Extensions

Extensions in the current project loaded automatically when running `mix protobuf.generate`. However they need to be already generated in order for `protobuf` to pick them up.

**TODO**

## Features

* Extensions in the current project are picked up automatically by `Protobuf.load_extensions()` (or can be provided as an argument to `protobuf.generate`).

* Allows integration into the codegen by using generator plugins. See `lib/generators/grpc.ex`


