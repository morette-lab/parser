defmodule Portal.Eval do
  alias Portal.{Token, Environment}

  alias Portal.Syntax.{
    Expression,
    Function,
    Grouping,
    Binary,
    Print,
    Unary,
    Var,
    If,
    Call
  }

  def by_parser({:ok, p}) do
    env = Environment.new()
    eval(env, p)

    :ok
  end

  def eval(env, []), do: {env, nil}

  def eval(env, [first | rest]) do
    {new_env, _result} = eval(env, first)
    eval(new_env, rest)
  end

  def eval(env, %Expression{content: content}), do: eval(env, content)

  def eval(env, %Binary{left: left, op: op, right: right}) do
    {env, left} = eval(env, left)
    {env, right} = eval(env, right)

    result =
      case op.id do
        :PLUS ->
          left + right

        :MINUS ->
          left - right

        :STAR ->
          left * right

        :SLASH ->
          left / right

        :BANG_EQUAL ->
          left != right

        :EQUAL_EQUAL ->
          left == right

        :GREATER ->
          left > right

        :GREATER_EQUAL ->
          left >= right

        :LESS ->
          left < right

        :LESS_EQUAL ->
          left <= right
      end

    {env, result}
  end

  def eval(env, %Unary{content: content, op: op}) do
    {env, value} = eval(env, content)

    result =
      case op.id do
        :BANG ->
          !value

        :MINUS ->
          -value
      end

    {env, result}
  end

  def eval(env, %Function{name: name} = fun) do
    env = Environment.put(env, name, fun)
    {env, nil}
  end

  def eval(env, %Call{fun_name: name, args: args}) do
    {contains?, scope} = Environment.contains?(env, name.value)

    if contains? do
      %Function{body: body, arguments: fun_args} = Environment.get(env, scope, name.value)

      if is_the_same_arity?(args, fun_args) do
        new_env =
          args
          |> Enum.reverse()
          |> Enum.zip(fun_args)
          |> Enum.reduce(Environment.new_scope(env), fn {v, id}, acc ->
            {_env, result} = eval(acc, v)
            Environment.put(acc, id, result)
          end)

        {env, result} = eval(new_env, body)
        {Environment.reset_current_scope(env), result}
      else
        raise "#{name.value} with #{count(args)} does not exists"
      end
    else
      raise "#{name.value} - Function does not exists"
    end
  end

  def eval(env, %Grouping{content: content}), do: eval(env, content)

  def eval(env, %Token{id: id, value: value}) do
    result =
      case id do
        :NUMBER ->
          String.to_integer(value)

        :BOOLEAN ->
          String.to_atom(value)

        :STRING ->
          String.replace(value, "\"", "")

        :NIL ->
          nil

        :LOWER_CASE_IDENTIFIER ->
          case Environment.get(env, value) do
            nil -> raise "Variable #{value} not found"
            var -> var
          end
      end

    {env, result}
  end

  def eval(env, %Print{content: content}) do
    {env, result} = eval(env, content)

    IO.inspect(result)

    {env, nil}
  end

  def eval(env, %Var{id: id, value: value}) do
    {env, v} = eval(env, value)
    {Environment.put(env, id, v), nil}
  end

  def eval(env, %If{condition: condition, content: content, else: nil}) do
    {env, condition} = eval(env, condition)

    if condition do
      {env, result} = eval(env, content)
      {Environment.reset_current_scope(env), result}
    else
      {env, nil}
    end
  end

  def eval(env, %If{condition: condition, content: content, else: else_content}) do
    {env, condition} = eval(env, condition)

    if condition do
      eval(env, content)
    else
      {env, result} = eval(env, else_content)
      {Environment.reset_current_scope(env), result}
    end
  end

  def is_the_same_arity?(call_args, fun_args), do: count(call_args) == count(fun_args)

  def count(enum), do: Enum.count(enum)
end
