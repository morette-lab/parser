defmodule Portal.Environment do
  alias __MODULE__

  defstruct current_scope: %{}, scope_out: %{}

  def new(), do: %Environment{}

  def get(env, key) do
    value = Map.get(env.current_scope, key)
    if is_nil(value), do: Map.get(env.scope_out, key), else: value
  end

  def get(env, :current_scope, key) do
    Map.get(env.current_scope, key)
  end

  def get(env, :scope_out, key) do
    Map.get(env.scope_out, key)
  end

  def contains?(env, key) do
    if Map.has_key?(env.current_scope, key) do
      {true, :current_scope}
    else
      {Map.has_key?(env.scope_out, key), :scope_out}
    end
  end

  def reset_current_scope(env) do
    %Environment{
      current_scope: %{},
      scope_out: env.scope_out
    }
  end

  def new_scope(env) do
    %Environment{
      current_scope: %{},
      scope_out: Map.merge(env.scope_out, env.current_scope)
    }
  end

  def put(env, key, value) do
    %Environment{
      current_scope: Map.put(env.current_scope, key, value),
      scope_out: env.scope_out
    }
  end
end
