defmodule Portal.Token do
  @enforce_keys [:id]

  defstruct [:id, :value]
end
