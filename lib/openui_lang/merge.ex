defmodule OpenUILang.Merge do
  @moduledoc false

  alias OpenUILang.ZigNIF

  @spec merge_statements(String.t(), String.t(), String.t()) :: String.t()
  def merge_statements(existing, patch, root_id \\ "root")
      when is_binary(existing) and is_binary(patch) do
    existing_stmts = ZigNIF.parse_merge_statements(existing, 0)
    patch_stmts = ZigNIF.parse_merge_statements(patch, 1)

    cond do
      existing_stmts == [] ->
        Enum.map_join(patch_stmts, "\n", fn {_id, raw, _is_null, _is_sb, _refs} -> raw end)

      patch_stmts == [] ->
        existing

      true ->
        {merged, meta_map, rev_order} =
          Enum.reduce(existing_stmts, {%{}, %{}, []}, fn {id, raw, _is_null, is_sb, refs},
                                                         {m, a, o} ->
            o = if Map.has_key?(m, id), do: o, else: [id | o]
            {Map.put(m, id, raw), Map.put(a, id, {is_sb, refs}), o}
          end)

        order = Enum.reverse(rev_order)

        {merged, meta_map, order} =
          Enum.reduce(patch_stmts, {merged, meta_map, order}, fn {id, raw, is_null, is_sb, refs},
                                                                 {m, a, o} ->
            if is_null do
              {Map.delete(m, id), Map.delete(a, id), List.delete(o, id)}
            else
              o = if Map.has_key?(m, id), do: o, else: o ++ [id]
              {Map.put(m, id, raw), Map.put(a, id, {is_sb, refs}), o}
            end
          end)

        {merged, order} = gc_unreachable(order, merged, meta_map, root_id)

        order
        |> Enum.filter(&Map.has_key?(merged, &1))
        |> Enum.map_join("\n", &Map.fetch!(merged, &1))
    end
  end

  defp gc_unreachable(order, merged, meta_map, root_id) do
    if not Map.has_key?(meta_map, root_id) do
      {merged, order}
    else
      reachable = bfs_reachable([root_id], MapSet.new([root_id]), meta_map)

      reachable =
        Enum.reduce(order, reachable, fn id, acc ->
          is_stream_or_bind? =
            case Map.get(meta_map, id) do
              {true, _} -> true
              _ -> false
            end

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

  defp bfs_reachable([], reachable, _meta_map), do: reachable

  defp bfs_reachable([id | rest], reachable, meta_map) do
    case Map.get(meta_map, id) do
      nil ->
        bfs_reachable(rest, reachable, meta_map)

      {_is_sb, refs} ->
        {new_refs, new_reachable} =
          Enum.reduce(refs, {[], reachable}, fn ref, {acc_q, r} ->
            if not MapSet.member?(r, ref) and Map.has_key?(meta_map, ref) do
              {[ref | acc_q], MapSet.put(r, ref)}
            else
              {acc_q, r}
            end
          end)

        bfs_reachable(Enum.reverse(new_refs, rest), new_reachable, meta_map)
    end
  end
end
