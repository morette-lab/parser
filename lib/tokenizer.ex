defmodule Portal.Tokenizer do
  use Portal.Macros.Tokenizer

  @program_words [
    %{regex: ~r/^def/, id: :DEF},
    %{regex: ~r/^do/, id: :DO_BLOCK},
    %{regex: ~r/^end/, id: :END_BLOCK},
    %{regex: ~r/^print/, id: :PRINT},
    %{regex: ~r/^if/, id: :IF},
    %{regex: ~r/^else/, id: :ELSE}
  ]

  @rules @program_words ++
           [
             %{regex: ~r/^\(/, id: :LEFT_PAREN},
             %{regex: ~r/^\)/, id: :RIGHT_PAREN},
             %{regex: ~r/^\+/, id: :PLUS},
             %{regex: ~r/^\-/, id: :MINUS},
             %{regex: ~r/^!=/, id: :BANG_EQUAL},
             %{regex: ~r/^==/, id: :EQUAL_EQUAL},
             %{regex: ~r/^>/, id: :GREATER},
             %{regex: ~r/^>=/, id: :GREATER_EQUAL},
             %{regex: ~r/^</, id: :LESS},
             %{regex: ~r/^<=/, id: :LESS_EQUAL},
             %{regex: ~r/^!=/, id: :BANG_EQUAL},
             %{regex: ~r/^=/, id: :EQUAL},
             %{regex: ~r/^\//, id: :SLASH},
             %{regex: ~r/^\*/, id: :STAR},
             %{regex: ~r/^\!/, id: :BANG},
             %{regex: ~r/^nil/, id: :NIL},
             %{regex: ~r/^,/, id: :COMMA},
             %{regex: ~r/^(true|false)/, id: :BOOLEAN, value?: true},
             %{regex: ~r/^\".*\"/, id: :STRING, value?: true},
             %{regex: ~r/^[a-z]+/, id: :LOWER_CASE_IDENTIFIER, value?: true},
             %{regex: ~r/^\w+/, id: :NUMBER, value?: true},
             %{regex: ~r/^\s/, ignore?: true},
             %{regex: ~r/^\n/, ignore?: true}
           ]

  def run(input) do
    tokenize(input)
  end
end
