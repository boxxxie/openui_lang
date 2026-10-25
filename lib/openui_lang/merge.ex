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
        {merged, asts, rev_order} =
          Enum.reduce(existing_stmts, {%{}, %{}, []}, fn stmt, {m, a, o} ->
            o = if Map.has_key?(m, stmt.id), do: o, else: [stmt.id | o]
            {Map.put(m, stmt.id, stmt.raw), Map.put(a, stmt.id, stmt.ast), o}
          end)

        order = Enum.reverse(rev_order)

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
      raw_slices = split_statement_source(closed)
      stmts = closed |> Lexer.tokenize() |> Statements.split()

      Enum.zip_with(raw_slices, stmts, fn raw, stmt ->
        %{id: stmt.id, ast: Expressions.parse_expression(stmt.tokens), raw: raw}
      end)
    end
  end

  defp split_statement_source(input) do
    do_split_source(input, input, 0, 0, 0, false, [])
  end

  defp do_split_source(orig, <<>>, i, start, _depth, _in_str, acc) do
    tail = binary_part(orig, start, i - start) |> String.trim()
    acc = if tail != "", do: [tail | acc], else: acc
    Enum.reverse(acc)
  end

  defp do_split_source(orig, <<"\\", _esc, rest::binary>>, i, start, depth, in_str, acc)
       when in_str != false do
    do_split_source(orig, rest, i + 2, start, depth, in_str, acc)
  end

  defp do_split_source(orig, <<c, rest::binary>>, i, start, depth, in_str, acc)
       when in_str != false do
    next_str = if c == in_str, do: false, else: in_str
    do_split_source(orig, rest, i + 1, start, depth, next_str, acc)
  end

  defp do_split_source(orig, <<c, rest::binary>>, i, start, depth, false, acc)
       when c in [?", ?'] do
    do_split_source(orig, rest, i + 1, start, depth, c, acc)
  end

  defp do_split_source(orig, <<c, rest::binary>>, i, start, depth, false, acc)
       when c in [?(, ?[, ?{] do
    do_split_source(orig, rest, i + 1, start, depth + 1, false, acc)
  end

  defp do_split_source(orig, <<c, rest::binary>>, i, start, depth, false, acc)
       when c in [?), ?], ?}] do
    do_split_source(orig, rest, i + 1, start, max(0, depth - 1), false, acc)
  end

  defp do_split_source(orig, <<"\n", rest::binary>>, i, start, depth, false, acc)
       when depth <= 0 do
    stmt = binary_part(orig, start, i - start) |> String.trim()
    acc = if stmt != "", do: [stmt | acc], else: acc
    do_split_source(orig, rest, i + 1, i + 1, depth, false, acc)
  end

  defp do_split_source(orig, <<_c, rest::binary>>, i, start, depth, false, acc) do
    do_split_source(orig, rest, i + 1, start, depth, false, acc)
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
        refs = AST.collect_refs(ast)

        {new_refs, new_reachable} =
          Enum.reduce(refs, {[], reachable}, fn ref, {acc_q, r} ->
            if not MapSet.member?(r, ref) and Map.has_key?(asts, ref) do
              {[ref | acc_q], MapSet.put(r, ref)}
            else
              {acc_q, r}
            end
          end)

        bfs_reachable(Enum.reverse(new_refs, rest), new_reachable, asts)
    end
  end
end
