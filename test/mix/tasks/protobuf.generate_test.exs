defmodule Mix.Tasks.Protobuf.GenerateTest do
  use ExUnit.Case, async: true

  # https://github.com/elixir-protobuf/protobuf/blob/main/test/protobuf/protoc/cli_integration_test.exs
  #
  import Mix.Tasks.Protobuf.Generate, only: [run: 1]
  import ProtobufGenerate.TestHelpers, only: [tmp_dir: 1]

  setup :tmp_dir

  describe "with simple user.proto file" do
    setup %{tmp_dir: tmp_dir} do
      proto_path = Path.join(tmp_dir, "user.proto")

      File.write!(proto_path, """
      syntax = "proto3";

      package foo;

      message User {
        string email = 1;
      }
      """)

      %{proto_path: proto_path}
    end

    test "simple compilation", %{tmp_dir: tmp_dir, proto_path: proto_path} do
      run([
        "--include-path=#{tmp_dir}",
        "--output-path=#{tmp_dir}",
        proto_path
      ])

      assert [mod] = compile_file_and_clean_modules_on_exit("#{tmp_dir}/user.pb.ex")
      assert mod == Foo.User
    end

    test "transform_module option", %{tmp_dir: tmp_dir, proto_path: proto_path} do
      run([
        "--include-path=#{tmp_dir}",
        "--output-path=#{tmp_dir}",
        "--transform-module=MyTransformer",
        proto_path
      ])

      assert [mod] = compile_file_and_clean_modules_on_exit("#{tmp_dir}/user.pb.ex")
      assert mod == Foo.User

      assert mod.transform_module() == MyTransformer
    end

    test "generate-descriptors option", %{tmp_dir: tmp_dir, proto_path: proto_path} do
      run([
        "--include-path=#{tmp_dir}",
        "--output-path=#{tmp_dir}",
        "--generate-descriptors=true",
        proto_path
      ])

      assert [mod] = compile_file_and_clean_modules_on_exit("#{tmp_dir}/user.pb.ex")
      assert mod == Foo.User

      assert %Google.Protobuf.DescriptorProto{} = descriptor = mod.descriptor()
      assert descriptor.name == "User"
    end

    test "package_prefix mypkg", %{tmp_dir: tmp_dir, proto_path: proto_path} do
      run([
        "--include-path=#{tmp_dir}",
        "--output-path=#{tmp_dir}",
        "--package-prefix=mypkg",
        proto_path
      ])

      assert [mod] = compile_file_and_clean_modules_on_exit("#{tmp_dir}/user.pb.ex")
      assert mod == Mypkg.Foo.User
    end

    # Regression test for https://github.com/elixir-protobuf/protobuf/issues/252
    test "with lowercase enum", %{tmp_dir: tmp_dir} do
      proto_path = Path.join(tmp_dir, "lowercase_enum.proto")

      File.write!(proto_path, """
      syntax = "proto3";

      enum lowercaseEnum {
        NOT_SET = 0;
        SET = 1;
      }

      message UsesLowercaseEnum {
        lowercaseEnum e = 1;
      }
      """)

      run([
        "--include-path=#{tmp_dir}",
        "--output-path=#{tmp_dir}",
        proto_path
      ])

      assert [LowercaseEnum, UsesLowercaseEnum] =
               compile_file_and_clean_modules_on_exit("#{tmp_dir}/lowercase_enum.pb.ex")
    end
  end

  # Regression test for https://github.com/elixir-protobuf/protobuf/issues/242
  test "with external packages and the package_prefix option", %{tmp_dir: tmp_dir} do
    proto_path = Path.join(tmp_dir, "timestamp_wrapper.proto")

    File.write!(proto_path, """
    syntax = "proto3";

    import "google/protobuf/timestamp.proto";

    message TimestampWrapper {
      google.protobuf.Timestamp some_time = 1;
    }
    """)

    run([
      "--include-path=#{tmp_dir}",
      "--include-path=#{Mix.Project.deps_paths().google_protobuf}/src",
      "--output-path=#{tmp_dir}",
      "--package-prefix=my_type",
      proto_path
    ])

    assert [mod] = compile_file_and_clean_modules_on_exit("#{tmp_dir}/timestamp_wrapper.pb.ex")

    assert mod == MyType.TimestampWrapper
    assert Map.fetch!(mod.__message_props__().field_props, 1).type == Google.Protobuf.Timestamp
  end

  test "with grpc plugin", %{tmp_dir: tmp_dir} do
    proto_path = Path.join(tmp_dir, "helloworld.proto")

    File.write!(proto_path, """
    syntax = "proto3";

    import "google/protobuf/timestamp.proto";

    package helloworld;

    service Greeter {
      rpc SayHello (HelloRequest) returns (HelloReply) {}
      rpc SayHelloFrom (HelloRequestFrom) returns (HelloReply) {}
    }

    message HelloRequest {
      string name = 1;
    }

    message HelloRequestFrom {
      string name = 1;
      string from = 2;
    }

    message HelloReply {
      string message = 1;
      google.protobuf.Timestamp today = 2;
    }
    """)

    run([
      "--include-path=#{tmp_dir}",
      "--include-path=#{Mix.Project.deps_paths().google_protobuf}/src",
      "--output-path=#{tmp_dir}",
      "--plugin=ProtobufGenerate.Plugins.GRPC",
      proto_path
    ])

    assert [_, _, _, service, stub] =
             compile_file_and_clean_modules_on_exit("#{tmp_dir}/helloworld.pb.ex")

    assert service == Helloworld.Greeter.Service
    assert stub == Helloworld.Greeter.Stub
    assert [{:SayHello, _, _, _}, {:SayHelloFrom, _, _, _}] = service.__rpc_calls__()
  end

  @tag :skip
  test "with grpc options plugin", %{tmp_dir: tmp_dir} do
    # proto_path = Path.join(tmp_dir, "helloworld_options.proto")
    proto_path = Path.join(tmp_dir, "helloworld_options.proto")
    paths = ["google/api/annotations.proto", "google/api/http.proto", "helloworld_options.proto"]

    File.write!(proto_path, """
    syntax = "proto3";

    import "google/api/annotations.proto";
    import "google/protobuf/timestamp.proto";

    package helloworld;

    service Greeter {
      rpc SayHello (HelloRequest) returns (HelloReply) {
        option (google.api.http) = {
          get: "/v1/greeter/{name}"
        };
      }
      rpc SayHelloFrom (HelloRequestFrom) returns (HelloReply) {
        option (google.api.http) = {
          post: "/v1/greeter"
          body: "*"
        };
      }
    }

    message HelloRequest {
      string name = 1;
    }

    message HelloRequestFrom {
      string name = 1;
      string from = 2;
    }

    message HelloReply {
      string message = 1;
      google.protobuf.Timestamp today = 2;
    }
    """)

    run (
      [
        "--include-path=#{tmp_dir}",
        "--output-path=#{tmp_dir}",
        "--include-path=#{Mix.Project.deps_paths().googleapis}",
        "google/api/annotations.proto",
        "google/api/http.proto"
      ]
    )
    _ = compile_file_and_clean_modules_on_exit("#{tmp_dir}/google/api/annotations.pb.ex")
    _ = compile_file_and_clean_modules_on_exit("#{tmp_dir}/google/api/http.pb.ex")
      # "--include-path=#{Mix.Project.deps_paths().google_protobuf}/src",
    run(
      [
        "--include-path=#{tmp_dir}",
        "--include-path=#{Mix.Project.deps_paths().googleapis}",
        "--output-path=#{tmp_dir}",
        "--plugin=ProtobufGenerate.Plugins.GRPCWithOptions"
      ] ++ paths
    )

    Code.ensure_loaded?(GRPC)

    assert [_, _, _, service, stub] =
             compile_file_and_clean_modules_on_exit("#{tmp_dir}/helloworld_options.pb.ex")

    assert service == Helloworld.Greeter.Service
    assert stub == Helloworld.Greeter.Stub
    assert [{:SayHello, _, _, opts1}, {:SayHelloFrom, _, _, opts2}] = service.__rpc_calls__()
    assert opts1 == %{}
    assert opts2 == %{}
  end


  defp compile_file_and_clean_modules_on_exit(path) do
    modules =
      path
      |> Code.compile_file()
      |> Enum.map(fn {mod, _bytecode} -> mod end)

    on_exit(fn ->
      Enum.each(modules, fn mod ->
        :code.purge(mod)
        :code.delete(mod)
      end)
    end)

    modules
  end
end
