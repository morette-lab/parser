defmodule Portal do
  alias Portal.{Eval, Parser, Tokenizer}

  def run(input_path) do
    input_path
    |> File.read!()
    |> Tokenizer.run()
    |> Parser.run()
    |> Eval.by_parser()
  end
end
