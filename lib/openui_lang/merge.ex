defmodule OpenUILang.Merge do
  @moduledoc false

  alias OpenUILang.{AST, Expressions, Lexer, Statements}

  @spec merge_statements(String.t(), String.t(), String.t()) :: String.t()
  def merge_statements(existing, patch, root_id \\ "root")
      when is_binary(existing) and is_binary(patch) do
    existing_stmts = parse_statements(existing)
    patch_stmts = patch |> Statements.strip_fences() |> parse_statements()

    cond do
      existing_stmts == [] ->
        Enum.map_join(patch_stmts, "\n", & &1.raw)

      patch_stmts == [] ->
        existing

      true ->
        {merged, asts, order} =
          Enum.reduce(existing_stmts, {%{}, %{}, []}, fn stmt, {m, a, o} ->
            {Map.put(m, stmt.id, stmt.raw), Map.put(a, stmt.id, stmt.ast), o ++ [stmt.id]}
          end)

        {merged, asts, order} =
          Enum.reduce(patch_stmts, {merged, asts, order}, fn stmt, {m, a, o} ->
            if stmt.ast.k == :null do
              {Map.delete(m, stmt.id), Map.delete(a, stmt.id), List.delete(o, stmt.id)}
            else
              o = if Map.has_key?(m, stmt.id), do: o, else: o ++ [stmt.id]
              {Map.put(m, stmt.id, stmt.raw), Map.put(a, stmt.id, stmt.ast), o}
            end
          end)

        {merged, order} = gc_unreachable(order, merged, asts, root_id)

        order
        |> Enum.filter(&Map.has_key?(merged, &1))
        |> Enum.map_join("\n", &Map.fetch!(merged, &1))
    end
  end

  defp parse_statements(input) do
    trimmed = input |> Statements.strip_comments() |> String.trim()

    if trimmed == "" do
      []
    else
      %{text: closed} = Statements.auto_close(trimmed)

      closed
      |> split_statement_source()
      |> Enum.flat_map(fn raw ->
        case raw |> Lexer.tokenize() |> Statements.split() do
          [stmt | _] ->
            [%{id: stmt.id, ast: Expressions.parse_expression(stmt.tokens), raw: raw}]

          [] ->
            []
        end
      end)
    end
  end

  defp split_statement_source(input) do
    do_split_source(input, 0, byte_size(input), 0, 0, false, false, [])
  end

  defp do_split_source(input, i, len, start, _depth, _in_str, _esc, acc) when i >= len do
    tail = binary_part(input, start, len - start) |> String.trim()
    acc = if tail != "", do: [tail | acc], else: acc
    Enum.reverse(acc)
  end

  defp do_split_source(input, i, len, start, depth, in_str, true, acc) do
    do_split_source(input, i + 1, len, start, depth, in_str, false, acc)
  end

  defp do_split_source(input, i, len, start, depth, in_str, false, acc) when in_str != false do
    c = :binary.at(input, i)

    cond do
      c == ?\\ ->
        do_split_source(input, i + 1, len, start, depth, in_str, true, acc)

      c == in_str ->
        do_split_source(input, i + 1, len, start, depth, false, false, acc)

      true ->
        do_split_source(input, i + 1, len, start, depth, in_str, false, acc)
    end
  end

  defp do_split_source(input, i, len, start, depth, false, false, acc) do
    c = :binary.at(input, i)

    cond do
      c in [?", ?'] ->
        do_split_source(input, i + 1, len, start, depth, c, false, acc)

      c in [?(, ?[, ?{] ->
        do_split_source(input, i + 1, len, start, depth + 1, false, false, acc)

      c in [?), ?], ?}] ->
        do_split_source(input, i + 1, len, start, max(0, depth - 1), false, false, acc)

      c == ?\n and depth <= 0 ->
        stmt = binary_part(input, start, i - start) |> String.trim()
        acc = if stmt != "", do: [stmt | acc], else: acc
        do_split_source(input, i + 1, len, i + 1, depth, false, false, acc)

      true ->
        do_split_source(input, i + 1, len, start, depth, false, false, acc)
    end
  end

  defp gc_unreachable(order, merged, asts, root_id) do
    if not Map.has_key?(asts, root_id) do
      {merged, order}
    else
      reachable = bfs_reachable([root_id], MapSet.new([root_id]), asts)

      reachable =
        Enum.reduce(order, reachable, fn id, acc ->
          ast = Map.get(asts, id)
          is_stream_or_bind? = is_map(ast) and Map.get(ast, :n) in ["StreamSource", "Bind"]

          if String.starts_with?(id, "$") or is_stream_or_bind? do
            MapSet.put(acc, id)
          else
            acc
          end
        end)

      new_order = Enum.filter(order, &MapSet.member?(reachable, &1))
      new_merged = Map.take(merged, new_order)
      {new_merged, new_order}
    end
  end

  defp bfs_reachable([], reachable, _asts), do: reachable

  defp bfs_reachable([id | rest], reachable, asts) do
    case Map.get(asts, id) do
      nil ->
        bfs_reachable(rest, reachable, asts)

      ast ->
        refs = collect_refs(ast)

        {new_queue, new_reachable} =
          Enum.reduce(refs, {rest, reachable}, fn ref, {q, r} ->
            if not MapSet.member?(r, ref) and Map.has_key?(asts, ref) do
              {q ++ [ref], MapSet.put(r, ref)}
            else
              {q, r}
            end
          end)

        bfs_reachable(new_queue, new_reachable, asts)
    end
  end

  defp collect_refs(node) do
    refs_table = :ets.new(:refs, [:set, :private])

    try do
      AST.walk_ast(node, fn
        %{k: :ref, n: n} -> :ets.insert(refs_table, {n, true})
        %{k: :runtime_ref, n: n} -> :ets.insert(refs_table, {n, true})
        _ -> :ok
      end)

      :ets.tab2list(refs_table) |> Enum.map(&elem(&1, 0))
    after
      :ets.delete(refs_table)
    end
  end
end
