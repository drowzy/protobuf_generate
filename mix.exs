defmodule ProtobufGenerate.MixProject do
  use Mix.Project

  @source_url "https://github.com/drowzy/protobuf_generate"
  @version "0.2.0"
  @description "Protobuf code generation as a mix task"

  def project do
    [
      app: :protobuf_generate,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      description: @description,
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp package do
    [
      maintainers: ["Simon Thörnqvist"],
      licenses: ["MIT"],
      files: ~w(
        mix.exs
        README.md
        lib/mix
        lib/protobuf_generate
        LICENSE
        .formatter.exs
      ),
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:protobuf, "~> 0.12"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:google_protobuf,
       github: "protocolbuffers/protobuf",
       branch: "main",
       submodules: true,
       app: false,
       compile: false,
       only: [:dev, :test]},
      {:googleapis,
       github: "googleapis/googleapis",
       branch: "master",
       app: false,
       compile: false,
       only: [:dev, :test]},
    ]
  end
end
