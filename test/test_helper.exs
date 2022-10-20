# https://github.com/elixir-protobuf/protobuf/blob/main/test/test_helper.exs
defmodule ProtobufGenerate.TestHelpers do
  import ExUnit.Assertions
  # TODO: Remove when we depend on Elixir 1.11+.
  def tmp_dir(context) do
    dir_name =
      "#{inspect(context[:case])}#{context[:describe]}#{context[:test]}"
      |> String.downcase()
      |> String.replace(["-", " ", ".", "_"], "_")

    tmp_dir_name = Path.join(System.tmp_dir!(), dir_name)

    File.rm_rf!(tmp_dir_name)
    File.mkdir_p!(tmp_dir_name)

    Map.put(context, :tmp_dir, tmp_dir_name)
  end

  # This code is taken from Code.fetch_docs/1 in Elixir (v1.13 in particular).
  def fetch_docs_from_bytecode(bytecode) when is_binary(bytecode) do
    docs_chunk = 'Docs'
    assert {:ok, {_module, [{^docs_chunk, bin}]}} = :beam_lib.chunks(bytecode, [docs_chunk])
    :erlang.binary_to_term(bin)
  end
end

ExUnit.start(excludes: [:skip])
