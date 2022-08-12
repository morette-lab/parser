defmodule Portal.JS.Transpile do
  @deprecated "Will no longer be updated"

  alias Portal.Token

  alias Portal.Syntax.{
    Expression,
    Function,
    Grouping,
    Binary,
    Print,
    Unary,
    Call
  }

  @output_folder "js_out"

  def by_parser({:ok, parser}, path) do
    case build_string(parser, "") do
      {:ok, output} ->
        :ok = folder()

        path
        |> file_name()
        |> write(output)
    end
  end

  def file_name(path) do
    path
    |> String.split("/")
    |> Enum.at(-1)
  end

  def folder() do
    case File.mkdir(@output_folder) do
      :ok -> :ok
      {:error, :eexist} -> :ok
    end
  end

  def write(file_name, content) do
    File.write("#{@output_folder}/#{file_name}.js", content)
  end

  def build_string([], str), do: {:ok, str}

  def build_string([%Function{arguments: arguments, body: nil, name: name} | rest], acc) do
    args = Enum.join(arguments, ", ")

    build_string(rest, acc <> "function #{name}(#{args}) {} ")
  end

  def build_string([%Function{arguments: arguments, body: body, name: name} | rest], acc) do
    args = Enum.join(arguments, ", ")
    body = translate_body_function(body)

    result = "function #{name}(#{args}) {
      #{body}} "

    build_string(rest, acc <> result)
  end

  def build_string([%Expression{content: content} | rest], acc) do
    build_string(rest, acc <> parse(content))
  end

  def build_string([%Print{content: content} | rest], acc) do
    result = "console.log(#{parse(content)})"

    build_string(rest, acc <> result)
  end

  def translate_body_function(%Expression{content: content}) do
    parse(content)
  end

  def parse(c) when is_binary(c), do: c

  def parse(c) when c.__struct__ == Binary do
    binary(c)
  end

  def parse(c) when c.__struct__ == Unary do
    unary(c)
  end

  def parse(c) when c.__struct__ == Grouping do
    grouping(c)
  end

  def parse(c) when c.__struct__ == Call do
    call(c)
  end

  def parse(%Token{id: id, value: nil}) do
    case id do
      :PLUS -> "+"
      :MINUS -> "-"
      :BANG -> "!"
      :BANG_EQUAL -> "!="
      :EQUAL_EQUAL -> "=="
      :GREATER -> ">"
      :GREATER_EQUAL -> ">="
      :LESS -> "<"
      :LESS_EQUAL -> "<="
      :SLASH -> "/"
      :STAR -> "*"
    end
  end

  def parse(%Token{value: value}), do: value

  def parse(%Expression{content: content}), do: parse(content)

  def binary(%Binary{left: left, op: op, right: right}) do
    left = parse(left)
    right = parse(right)
    op = parse(op)

    "#{left} #{op} #{right}"
  end

  def unary(%Unary{content: content, op: op}) do
    content = parse(content)

    "#{op}#{content}"
  end

  def grouping(%Grouping{content: content}) do
    content = parse(content)

    "(#{content})"
  end

  def call(%Call{fun_name: fun_name, args: []}) do
    "#{parse(fun_name)}()"
  end

  def call(%Call{fun_name: fun_name, args: args}) do
    args =
      args
      |> Enum.map(&parse/1)
      |> Enum.join(", ")

    "#{parse(fun_name)}(#{args})"
  end
end
