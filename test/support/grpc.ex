# To test GRPC code gen
defmodule GRPC.Service do
  defmacro __using__(opts) do
    quote do
      import GRPC.Service, only: [rpc: 3, stream: 1]

      Module.register_attribute(__MODULE__, :rpc_calls, accumulate: true)
      @before_compile GRPC.Service

      def __meta__(:name), do: unquote(opts[:name])
    end
  end

  defmacro __before_compile__(env) do
    rpc_calls = Module.get_attribute(env.module, :rpc_calls)

    quote do
      def __rpc_calls__, do: unquote(rpc_calls |> Macro.escape() |> Enum.reverse())
    end
  end

  def stream(param) do
    quote do: {unquote(param), true}
  end

  defmacro rpc(name, request, reply, options \\ quote(do: %{})) do
    quote do
      @rpc_calls {unquote(name), unquote(request), unquote(reply),
                  unquote(options)}
    end
  end
end

defmodule GRPC.Stub do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
    end
  end
end
