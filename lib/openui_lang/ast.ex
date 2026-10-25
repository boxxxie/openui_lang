defmodule OpenUILang.AST do
  @moduledoc false

  @ast_kinds [
    :comp,
    :ref,
    :state_ref,
    :runtime_ref,
    :bin_op,
    :unary_op,
    :ternary,
    :member,
    :index,
    :assign,
    :str,
    :num,
    :bool,
    :null,
    :arr,
    :obj,
    :ph
  ]

  @runtime_expr_kinds [
    :state_ref,
    :runtime_ref,
    :bin_op,
    :unary_op,
    :ternary,
    :member,
    :index,
    :assign
  ]

  @spec is_ast_node?(term()) :: boolean()
  def is_ast_node?(%{k: k}) when k in @ast_kinds, do: true
  def is_ast_node?(_), do: false

  @spec is_runtime_expr?(term()) :: boolean()
  def is_runtime_expr?(%{k: k}) when k in @runtime_expr_kinds, do: true
  def is_runtime_expr?(_), do: false

  @spec is_element_node?(term()) :: boolean()
  def is_element_node?(%{type: "element", type_name: _, props: _}), do: true
  def is_element_node?(_), do: false

  @spec walk_ast(map(), (map() -> term())) :: :ok
  def walk_ast(node, visit) when is_map(node) and is_function(visit, 1) do
    visit.(node)

    case node do
      %{k: :comp, args: args} = comp ->
        Enum.each(args, &walk_ast(&1, visit))

        if mapped = Map.get(comp, :mapped_props) do
          Enum.each(Map.values(mapped), &walk_ast(&1, visit))
        end

      %{k: :arr, els: els} ->
        Enum.each(els, &walk_ast(&1, visit))

      %{k: :obj, entries: entries} ->
        Enum.each(entries, fn {_k, v} -> walk_ast(v, visit) end)

      %{k: :bin_op, left: left, right: right} ->
        walk_ast(left, visit)
        walk_ast(right, visit)

      %{k: :unary_op, operand: operand} ->
        walk_ast(operand, visit)

      %{k: :ternary, cond: cond_node, then: then_node, else: else_node} ->
        walk_ast(cond_node, visit)
        walk_ast(then_node, visit)
        walk_ast(else_node, visit)

      %{k: :member, obj: obj} ->
        walk_ast(obj, visit)

      %{k: :index, obj: obj, index: index} ->
        walk_ast(obj, visit)
        walk_ast(index, visit)

      %{k: :assign, value: value} ->
        walk_ast(value, visit)

      _ ->
        :ok
    end

    :ok
  end

  def walk_ast(_, _), do: :ok

  @spec collect_state_refs(term()) :: [String.t()]
  def collect_state_refs(node) do
    if is_ast_node?(node) do
      case collect_state_refs_rec(node, []) do
        [] -> []
        [single] -> [single]
        list -> list |> Enum.reverse() |> Enum.uniq()
      end
    else
      []
    end
  end

  @spec collect_refs(term()) :: [String.t()]
  def collect_refs(node) do
    if is_ast_node?(node) do
      case collect_refs_rec(node, []) do
        [] -> []
        [single] -> [single]
        list -> list |> Enum.reverse() |> Enum.uniq()
      end
    else
      []
    end
  end

  @spec collect_refs_and_state_refs(term()) :: {[String.t()], [String.t()]}
  def collect_refs_and_state_refs(node) do
    if is_ast_node?(node) do
      {refs, state_refs} = collect_both_rec(node, {[], []})

      refs =
        case refs do
          [] -> []
          [single] -> [single]
          list -> list |> Enum.reverse() |> Enum.uniq()
        end

      state_refs =
        case state_refs do
          [] -> []
          [single] -> [single]
          list -> list |> Enum.reverse() |> Enum.uniq()
        end

      {refs, state_refs}
    else
      {[], []}
    end
  end

  defp collect_both_rec(%{k: :state_ref, n: n}, {r, sr}), do: {r, [n | sr]}
  defp collect_both_rec(%{k: k, n: n}, {r, sr}) when k in [:ref, :runtime_ref], do: {[n | r], sr}

  defp collect_both_rec(%{k: :comp, args: args} = comp, acc) do
    acc = Enum.reduce(args, acc, &collect_both_rec/2)

    if mapped = Map.get(comp, :mapped_props) do
      Enum.reduce(Map.values(mapped), acc, &collect_both_rec/2)
    else
      acc
    end
  end

  defp collect_both_rec(%{k: :arr, els: els}, acc) do
    Enum.reduce(els, acc, &collect_both_rec/2)
  end

  defp collect_both_rec(%{k: :obj, entries: entries}, acc) do
    Enum.reduce(entries, acc, fn {_k, v}, a -> collect_both_rec(v, a) end)
  end

  defp collect_both_rec(%{k: :bin_op, left: l, right: r}, acc) do
    acc = collect_both_rec(l, acc)
    collect_both_rec(r, acc)
  end

  defp collect_both_rec(%{k: :unary_op, operand: op}, acc) do
    collect_both_rec(op, acc)
  end

  defp collect_both_rec(%{k: :ternary, cond: c, then: t, else: e}, acc) do
    acc
    |> then(&collect_both_rec(c, &1))
    |> then(&collect_both_rec(t, &1))
    |> then(&collect_both_rec(e, &1))
  end

  defp collect_both_rec(%{k: :member, obj: obj}, acc) do
    collect_both_rec(obj, acc)
  end

  defp collect_both_rec(%{k: :index, obj: obj, index: idx}, acc) do
    acc = collect_both_rec(obj, acc)
    collect_both_rec(idx, acc)
  end

  defp collect_both_rec(%{k: :assign, value: val}, acc) do
    collect_both_rec(val, acc)
  end

  defp collect_both_rec(_, acc), do: acc

  defp collect_refs_rec(%{k: k, n: n}, acc) when k in [:ref, :runtime_ref], do: [n | acc]

  defp collect_refs_rec(%{k: :comp, args: args} = comp, acc) do
    acc = Enum.reduce(args, acc, &collect_refs_rec/2)

    if mapped = Map.get(comp, :mapped_props) do
      Enum.reduce(Map.values(mapped), acc, &collect_refs_rec/2)
    else
      acc
    end
  end

  defp collect_refs_rec(%{k: :arr, els: els}, acc) do
    Enum.reduce(els, acc, &collect_refs_rec/2)
  end

  defp collect_refs_rec(%{k: :obj, entries: entries}, acc) do
    Enum.reduce(entries, acc, fn {_k, v}, a -> collect_refs_rec(v, a) end)
  end

  defp collect_refs_rec(%{k: :bin_op, left: l, right: r}, acc) do
    acc = collect_refs_rec(l, acc)
    collect_refs_rec(r, acc)
  end

  defp collect_refs_rec(%{k: :unary_op, operand: op}, acc) do
    collect_refs_rec(op, acc)
  end

  defp collect_refs_rec(%{k: :ternary, cond: c, then: t, else: e}, acc) do
    acc
    |> then(&collect_refs_rec(c, &1))
    |> then(&collect_refs_rec(t, &1))
    |> then(&collect_refs_rec(e, &1))
  end

  defp collect_refs_rec(%{k: :member, obj: obj}, acc) do
    collect_refs_rec(obj, acc)
  end

  defp collect_refs_rec(%{k: :index, obj: obj, index: idx}, acc) do
    acc = collect_refs_rec(obj, acc)
    collect_refs_rec(idx, acc)
  end

  defp collect_refs_rec(%{k: :assign, value: val}, acc) do
    collect_refs_rec(val, acc)
  end

  defp collect_refs_rec(_, acc), do: acc

  @spec any_ast?(term(), (map() -> boolean())) :: boolean()
  def any_ast?(node, pred) when is_map(node) and is_function(pred, 1) do
    if pred.(node) do
      true
    else
      case node do
        %{k: :comp, args: args} = comp ->
          Enum.any?(args, &any_ast?(&1, pred)) or
            case Map.get(comp, :mapped_props) do
              nil -> false
              mapped -> mapped |> Map.values() |> Enum.any?(&any_ast?(&1, pred))
            end

        %{k: :arr, els: els} ->
          Enum.any?(els, &any_ast?(&1, pred))

        %{k: :obj, entries: entries} ->
          Enum.any?(entries, fn {_k, v} -> any_ast?(v, pred) end)

        %{k: :bin_op, left: left, right: right} ->
          any_ast?(left, pred) or any_ast?(right, pred)

        %{k: :unary_op, operand: operand} ->
          any_ast?(operand, pred)

        %{k: :ternary, cond: cond_node, then: then_node, else: else_node} ->
          any_ast?(cond_node, pred) or any_ast?(then_node, pred) or any_ast?(else_node, pred)

        %{k: :member, obj: obj} ->
          any_ast?(obj, pred)

        %{k: :index, obj: obj, index: index} ->
          any_ast?(obj, pred) or any_ast?(index, pred)

        %{k: :assign, value: value} ->
          any_ast?(value, pred)

        _ ->
          false
      end
    end
  end

  def any_ast?(_, _), do: false

  defp collect_state_refs_rec(%{k: :state_ref, n: n}, acc), do: [n | acc]

  defp collect_state_refs_rec(%{k: :comp, args: args} = comp, acc) do
    acc = Enum.reduce(args, acc, &collect_state_refs_rec/2)

    if mapped = Map.get(comp, :mapped_props) do
      Enum.reduce(Map.values(mapped), acc, &collect_state_refs_rec/2)
    else
      acc
    end
  end

  defp collect_state_refs_rec(%{k: :arr, els: els}, acc) do
    Enum.reduce(els, acc, &collect_state_refs_rec/2)
  end

  defp collect_state_refs_rec(%{k: :obj, entries: entries}, acc) do
    Enum.reduce(entries, acc, fn {_k, v}, a -> collect_state_refs_rec(v, a) end)
  end

  defp collect_state_refs_rec(%{k: :bin_op, left: l, right: r}, acc) do
    acc = collect_state_refs_rec(l, acc)
    collect_state_refs_rec(r, acc)
  end

  defp collect_state_refs_rec(%{k: :unary_op, operand: op}, acc) do
    collect_state_refs_rec(op, acc)
  end

  defp collect_state_refs_rec(%{k: :ternary, cond: c, then: t, else: e}, acc) do
    acc
    |> then(&collect_state_refs_rec(c, &1))
    |> then(&collect_state_refs_rec(t, &1))
    |> then(&collect_state_refs_rec(e, &1))
  end

  defp collect_state_refs_rec(%{k: :member, obj: obj}, acc) do
    collect_state_refs_rec(obj, acc)
  end

  defp collect_state_refs_rec(%{k: :index, obj: obj, index: idx}, acc) do
    acc = collect_state_refs_rec(obj, acc)
    collect_state_refs_rec(idx, acc)
  end

  defp collect_state_refs_rec(%{k: :assign, value: val}, acc) do
    collect_state_refs_rec(val, acc)
  end

  defp collect_state_refs_rec(_, acc), do: acc

  @spec to_literal_ast(term()) :: map()
  def to_literal_ast(nil), do: %{k: :null}
  def to_literal_ast(v) when is_binary(v), do: %{k: :str, v: v}
  def to_literal_ast(v) when is_number(v), do: %{k: :num, v: v}
  def to_literal_ast(v) when is_boolean(v), do: %{k: :bool, v: v}
  def to_literal_ast(v) when is_list(v), do: %{k: :arr, els: Enum.map(v, &to_literal_ast/1)}

  def to_literal_ast(v) when is_map(v) do
    entries =
      v
      |> Map.drop(["__keys__"])
      |> Enum.map(fn {k, val} -> {to_string(k), to_literal_ast(val)} end)

    %{k: :obj, entries: entries}
  end

  def to_literal_ast(_), do: %{k: :null}

  @spec literal_value(map()) :: {:ok, term()} | :error
  def literal_value(%{k: k, v: v}) when k in [:str, :num, :bool], do: {:ok, v}
  def literal_value(%{k: :null}), do: {:ok, nil}

  def literal_value(%{k: :arr, els: els}) do
    Enum.reduce_while(els, {:ok, []}, fn e, {:ok, acc} ->
      case literal_value(e) do
        {:ok, v} -> {:cont, {:ok, [v | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      :error -> :error
    end
  end

  def literal_value(%{k: :obj, entries: entries}) do
    Enum.reduce_while(entries, {:ok, %{}}, fn {k, e}, {:ok, acc} ->
      case literal_value(e) do
        {:ok, v} -> {:cont, {:ok, Map.put(acc, k, v)}}
        :error -> {:halt, :error}
      end
    end)
  end

  def literal_value(_), do: :error
end
