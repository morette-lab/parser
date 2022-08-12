defmodule Portal.Parser do
  alias __MODULE__

  alias Portal.Token

  alias Portal.Syntax.{
    Expression,
    Grouping,
    Function,
    Binary,
    Print,
    Unary,
    Call,
    Var,
    If
  }

  defstruct [:prev, :curr, :rest]

  def run(tokens) do
    tokens
    |> from_tokens()
    |> do_run([])
  end

  defp do_run(%Parser{curr: nil, rest: []}, acc) do
    {:ok, acc}
  end

  defp do_run(p, acc) do
    {p, stmt} = parse(p)
    do_run(p, acc ++ [stmt])
  end

  def parse(%Parser{curr: %Token{id: :DEF}} = p) do
    next_token(p)
    |> parse_function_decl()
  end

  def parse(
        %Parser{
          curr: %Token{id: :LOWER_CASE_IDENTIFIER},
          rest: [%Token{id: :EQUAL} | _rest]
        } = p
      ) do
    parse_var_decl(p)
  end

  def parse(p) do
    parse_statement(p)
  end

  def parse_function_decl([]), do: raise("Incomplete expression")

  def parse_function_decl(p) do
    {p, func_name} = expect_and_get(p, :LOWER_CASE_IDENTIFIER)
    p = expect(p, :LEFT_PAREN)
    {p, args} = parse_function_arguments(p)
    p = expect(p, :RIGHT_PAREN)
    p = expect(p, :DO_BLOCK)
    {p, body} = parse_function_body(p)
    p = expect(p, :END_BLOCK)

    {p, %Function{name: func_name, arguments: args, body: body}}
  end

  def parse_function_arguments(p) do
    parse_function_arguments(p, [])
  end

  def parse_function_arguments(%Parser{curr: %Token{id: :COMMA}}, []) do
    raise "Unexpected comma"
  end

  def parse_function_arguments(%Parser{curr: %Token{id: :COMMA}} = p, arguments) do
    p
    |> next_token()
    |> parse_function_arguments(arguments)
  end

  def parse_function_arguments(%Parser{curr: nil}, _arguments) do
    raise "Expected :RIGHT_PAREN or :LOWER_CASE_IDENTIFIER"
  end

  def parse_function_arguments(%Parser{curr: %Token{id: :RIGHT_PAREN}} = p, arguments) do
    {p, arguments}
  end

  def parse_function_arguments(
        %Parser{
          curr: %Token{id: :LOWER_CASE_IDENTIFIER, value: value},
          prev: prev
        } = p,
        arguments
      ) do
    if prev.id == :COMMA or prev.id == :LEFT_PAREN do
      p
      |> next_token()
      |> parse_function_arguments(arguments ++ [value])
    else
      raise "Expected :COMMA or :LEFT_PAREN as previous token"
    end
  end

  def parse_function_arguments(_p, _arguments) do
    raise "Error parsing arguments"
  end

  def parse_function_body(p), do: parse_function_body(p, [])

  def parse_function_body(p, acc) do
    {p, result} =
      cond do
        match(p, :END_BLOCK) ->
          {p, nil}

        match(p, :LOWER_CASE_IDENTIFIER) ->
          parse_var_decl(p)

        true ->
          parse_statement(p)
      end

    if is_nil(result) do
      {p, acc}
    else
      parse_function_body(p, acc ++ [result])
    end
  end

  def parse_var_decl(p) do
    {p, var_name} = expect_and_get(p, :LOWER_CASE_IDENTIFIER)
    p = expect(p, :EQUAL)
    {p, expr} = parse_expression(p)

    {p, %Var{id: var_name, value: expr}}
  end

  def parse_statement(p) do
    cond do
      match(p, :PRINT) ->
        parse_print_stmt(next_token(p))

      match(p, :IF) ->
        parse_if_stmt(next_token(p))

      true ->
        parse_expression(p)
    end
  end

  def parse_if_stmt(p) do
    p = expect(p, :LEFT_PAREN)
    {p, expr} = parse_expression(p)
    p = expect(p, :RIGHT_PAREN)
    p = expect(p, :DO_BLOCK)

    {p, if_body} = parse_if_content(p)

    cond do
      match(p, :END_BLOCK) ->
        {next_token(p), %If{condition: expr, content: if_body}}

      match(p, :ELSE) ->
        {p, result} = parse_if_content(next_token(p))
        p = expect(p, :END_BLOCK)
        {p, %If{condition: expr, content: if_body, else: result}}

      true ->
        raise "Expected ELSE of END"
    end
  end

  def parse_if_content(p), do: parse_if_content(p, [])

  def parse_if_content(p, acc) do
    {p, result} =
      cond do
        match(p, :END_BLOCK) ->
          {p, nil}

        match(p, :ELSE) ->
          {p, nil}

        match_var_decl?(p) ->
          parse_var_decl(p)

        true ->
          parse_statement(p)
      end

    if is_nil(result) do
      {p, acc}
    else
      parse_if_content(p, acc ++ [result])
    end
  end

  def match_var_decl?(%Parser{
        curr: %Token{id: :LOWER_CASE_IDENTIFIER},
        rest: [%Token{id: :EQUAL} | _rest]
      }),
      do: true

  def match_var_decl?(_p), do: false

  def parse_print_stmt(p) do
    p = expect(p, :LEFT_PAREN)
    {p, expr} = parse_expression(p)
    p = expect(p, :RIGHT_PAREN)
    {p, %Print{content: expr}}
  end

  def parse_expression(p) do
    {p, eq} = parse_equality(p)
    {p, %Expression{content: eq}}
  end

  def parse_equality(p) do
    {p, left} = parse_comparison(p)
    parse_equality_expr(p, left)
  end

  def parse_equality_expr(p, left) do
    if Kernel.or(match(p, :BANG_EQUAL), match(p, :EQUAL_EQUAL)) do
      {p, op} = get_curr_token(p)
      {p, comparison} = parse_comparison(p)
      bin = %Binary{left: left, right: comparison, op: op}
      parse_equality_expr(p, bin)
    else
      {p, left}
    end
  end

  def parse_comparison(p) do
    {p, left} = parse_term(p)
    parse_comparison_expr(p, left)
  end

  def parse_comparison_expr(p, left) do
    match? =
      match(p, :GREATER)
      |> Kernel.or(match(p, :GREATER_EQUAL))
      |> Kernel.or(match(p, :LESS))
      |> Kernel.or(match(p, :LESS_EQUAL))

    if match? do
      {p, op} = get_curr_token(p)
      {p, term} = parse_term(p)
      bin = %Binary{left: left, right: term, op: op}
      parse_comparison_expr(p, bin)
    else
      {p, left}
    end
  end

  def parse_term(p) do
    {p, left} = parse_factor(p)
    parse_term_expr(p, left)
  end

  def parse_term_expr(p, left) do
    if Kernel.or(match(p, :MINUS), match(p, :PLUS)) do
      {p, op} = get_curr_token(p)
      {p, right} = parse_factor(p)
      bin = %Binary{left: left, right: right, op: op}
      parse_term_expr(p, bin)
    else
      {p, left}
    end
  end

  def parse_factor(p) do
    {p, left} = parse_unary(p)
    parse_factor_expr(p, left)
  end

  def parse_factor_expr(p, left) do
    if Kernel.or(match(p, :SLASH), match(p, :STAR)) do
      {p, op} = get_curr_token(p)
      {p, right} = parse_unary(p)
      bin = %Binary{left: left, right: right, op: op}
      parse_factor_expr(p, bin)
    else
      {p, left}
    end
  end

  def parse_unary(p) do
    if Kernel.or(match(p, :BANG), match(p, :MINUS)) do
      {p, op} = get_curr_token(p)
      {p, content} = parse_primary(p)
      una = %Unary{op: op, content: content}
      {p, una}
    else
      parse_call(p)
    end
  end

  def parse_call(p) do
    {p, left} = parse_primary(p)
    parse_call_expr(p, left)
  end

  def parse_call_expr(p, left) do
    if match(p, :LEFT_PAREN) do
      if match(next_token(p), :RIGHT_PAREN) do
        {p
         |> next_token()
         |> next_token(), %Call{fun_name: left}}
      else
        {p, args} = parse_arguments(next_token(p))
        p = expect(p, :RIGHT_PAREN)
        {p, %Call{fun_name: left, args: parse_args(args)}}
      end
    else
      {p, left}
    end
  end

  def parse_arguments(p) do
    {p, left} = parse_expression(p)
    parse_arguments_expr(p, left)
  end

  def parse_arguments_expr(p, left) do
    if match(p, :COMMA) do
      {p, expr} = parse_arguments(next_token(p))
      {p, [expr, left]}
    else
      {p, left}
    end
  end

  def parse_args(a) when is_list(a), do: List.flatten(a)

  def parse_args(a), do: [a]

  def parse_primary(p) do
    is_primary? =
      match(p, :STRING)
      |> Kernel.or(match(p, :NUMBER))
      |> Kernel.or(match(p, :BOOLEAN))
      |> Kernel.or(match(p, :NIL))
      |> Kernel.or(match(p, :LOWER_CASE_IDENTIFIER))

    cond do
      is_primary? ->
        {p, pri} = get_curr_token(p)
        {p, pri}

      match(p, :LEFT_PAREN) ->
        {p, expr} = parse_expression(next_token(p))
        p = expect(p, :RIGHT_PAREN)
        {p, %Grouping{content: expr.content}}

      true ->
        raise "Something is wrong! parse_primary: #{inspect(p)}"
    end
  end

  # utils

  alias Portal.Token
  alias Portal.Parser

  defp expect(%Parser{curr: nil}, expected_id) do
    raise "Expected: #{expected_id}, Got: nil"
  end

  defp expect(%Parser{curr: %Token{id: id}} = p, expected_id) do
    if id == expected_id do
      next_token(p)
    else
      raise "Expected: #{expected_id}, Got: #{id}"
    end
  end

  def get_prev_token(%Parser{prev: token}), do: token

  defp get_curr_token(%Parser{curr: curr} = p) do
    {next_token(p), curr}
  end

  defp expect_and_get(%Parser{curr: %Token{id: id, value: value}} = p, expected_id) do
    if id == expected_id do
      {next_token(p), value}
    else
      raise "Expected: #{expected_id}, Got: #{id}"
    end
  end

  defp next_token(%Parser{curr: curr, rest: []} = p) do
    %{p | prev: curr, rest: [], curr: nil}
  end

  defp next_token(%Parser{curr: curr, prev: _prev, rest: [head | tail]} = p) do
    %{p | prev: curr, rest: tail, curr: head}
  end

  defp from_tokens([first | rest]) do
    %Parser{curr: first, rest: rest, prev: nil}
  end

  def match(%Parser{curr: %Token{id: expected}}, expected), do: true

  def match(_parser, _expected), do: false
end
