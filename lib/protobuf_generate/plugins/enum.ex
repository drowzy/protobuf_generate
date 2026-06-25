defmodule ProtobufGenerate.Plugins.Enum do
  # ref: https://github.com/elixir-protobuf/protobuf/blob/main/lib/protobuf/protoc/generator/enum.ex
  @moduledoc false
  @behaviour ProtobufGenerate.Plugin

  alias Protobuf.Protoc.Context
  alias Protobuf.Protoc.Generator.Comment
  alias Protobuf.Protoc.Generator.Util

  @impl true
  def template do
    """
    defmodule <%= @module %> do
    <%= if @include_docs? and @comments != "" do %>
      @moduledoc \"\"\"
    <%= @comments %>
      \"\"\"<% else %>
      @moduledoc false<% end %>
      use Protobuf, <%= @use_options %>

      <%= if @descriptor_fun_body do %>
      def descriptor do
        # credo:disable-for-next-line
        <%= @descriptor_fun_body %>
      end
      <% end %>

      <%= for %Google.Protobuf.EnumValueDescriptorProto{name: name, number: number} <- @fields do %>
      field :<%= name %>, <%= number %><% end %>
    end
    """
  end

  @impl true
  def generate(ctx, %Google.Protobuf.FileDescriptorProto{enum_type: enum_types}) do
    Enum.with_index(enum_types, fn enum_type, index ->
      ctx = Context.append_comment_path(ctx, "5.#{index}")
      generate(ctx, enum_type)
    end)
  end

  def generate(%Context{namespace: ns} = ctx, %Google.Protobuf.EnumDescriptorProto{} = desc) do
    msg_name = Util.mod_name(ctx, ns ++ [Macro.camelize(desc.name)])
    comments = generate_comments(ctx, desc)

    use_options =
      Util.options_to_str(%{
        syntax: ctx.syntax,
        enum: true,
        protoc_gen_elixir_version: Util.version()
      })

    descriptor_fun_body =
      if ctx.gen_descriptors? do
        Util.descriptor_fun_body(desc)
      else
        nil
      end

    {msg_name,
     [
       module: msg_name,
       use_options: use_options,
       fields: desc.value,
       descriptor_fun_body: descriptor_fun_body,
       comments: comments,
       include_docs?: ctx.include_docs?
     ]}
  end

  defp generate_comments(ctx, desc) do
    enum_comments = Comment.get(ctx)

    values =
      Enum.with_index(desc.value, fn value, index ->
        ctx = Context.append_comment_path(ctx, "2.#{index}")
        {value.number, value_comment(ctx, value)}
      end)
      |> Enum.sort_by(fn {number, _comment} -> number end)
      |> Enum.map(fn {_number, comment} -> comment end)

    field_rows =
      Enum.map(values, fn {row, _additional} -> row end)
      |> Enum.join("\n")

    additional_notes =
      Enum.reject(values, fn {_row, additional} -> is_nil(additional) end)
      |> Enum.map(fn {_row, additional} -> additional end)
      |> Enum.join("\n")

    moduledoc =
      cond do
        field_rows == "" ->
          enum_comments

        additional_notes == "" ->
          """
          #{enum_comments}

          ## Values

          | # | Name | Notes |
          |---|------|-------|
          #{field_rows}
          """

        :else ->
          """
          #{enum_comments}

          ## Values

          | # | Name | Notes |
          |---|------|-------|
          #{field_rows}

          ### Additional Notes

          #{additional_notes}
          """
      end

    indent(moduledoc, 2)
  end

  defp value_comment(ctx, value) do
    comments =
      Comment.get(ctx)
      |> String.trim_trailing("\n")

    case String.split(comments, "\n") do
      [] ->
        row = "| #{value.number} | **`#{value.name}`** | |"
        {row, nil}

      [one_line] ->
        row = "| #{value.number} | **`#{value.name}`** | #{one_line} |"
        {row, nil}

      [first_line | rest] ->
        row = "| #{value.number} | **`#{value.name}`** | #{first_line} |"

        additional =
          "  * `#{value.name}`: #{first_line}\n" <> indent(Enum.join(rest, "\n"), 4)

        {row, additional}
    end
  end

  defp indent(comments, count) do
    comments
    |> String.split("\n")
    |> Enum.map_join("\n", fn
      "" -> ""
      line -> String.duplicate(" ", count) <> line
    end)
  end
end
