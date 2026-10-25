defmodule OpenUILang.Parser do
  @moduledoc false

  alias OpenUILang.{AST, Builtins, Materialize, Schema, Statements, ZigNIF}

  @default_root_id "root"

  defstruct [
    :cat,
    :root_name,
    buf: "",
    cleaned: "",
    has_fences: false,
    completed_end: 0,
    completed_raw_end: 0,
    completed_stmt_map: %{},
    completed_stmt_order: [],
    completed_count: 0,
    completed_syms: %{},
    completed_unreached: MapSet.new(),
    completed_state_decls: %{},
    completed_Init_state: %{},
    completed_queries: [],
    completed_mutations: [],
    mat_cache: %{},
    rev_deps: %{}
  ]

  @type t :: %__MODULE__{}

  @spec empty_result(boolean()) :: map()
  def empty_result(incomplete \\ true) do
    %{
      root: nil,
      meta: %{
        incomplete: incomplete,
        unresolved: [],
        orphaned: [],
        statement_count: 0,
        errors: []
      },
      state_declarations: %{},
      query_statements: [],
      mutation_statements: []
    }
  end

  @spec parse(String.t(), map() | nil, String.t() | nil) :: map()
  def parse(input, cat, root_name \\ nil) when is_binary(input) do
    root_name = root_name || (cat && Map.get(cat, :root))

    case ZigNIF.parse_source(input, 0) do
      :empty ->
        empty_result()

      {was_incomplete, []} ->
        empty_result(was_incomplete)

      {was_incomplete, classified_stmts} ->
        {stmt_map, rev_order} =
          Enum.reduce(classified_stmts, {%{}, []}, fn stmt, {acc_map, acc_order} ->
            acc_order =
              if Map.has_key?(acc_map, stmt.id), do: acc_order, else: [stmt.id | acc_order]

            {Map.put(acc_map, stmt.id, stmt), acc_order}
          end)

        stmt_order = Enum.reverse(rev_order)
        typed_stmts = Enum.map(stmt_order, &Map.fetch!(stmt_map, &1))

        {res, _cache} =
          build_result(
            stmt_map,
            typed_stmts,
            was_incomplete,
            map_size(stmt_map),
            cat,
            root_name,
            nil,
            nil,
            nil
          )

        res
    end
  end

  @doc """
  Parses an OpenUI Lang source string (complete or mid-stream partial) into a flat
  symbol table map `%{"root" => {"Panel", [...]}, "$var" => "default", ...}` where:
  - Component calls are `{component_name, args_list}` tuples
  - Forward references are `{:ref, identifier}` tuples
  - Reactive state bindings are `{:var, "$identifier"}` tuples
  - State variable declarations (`$var = value`) store `"$var" => value` directly in the map

  Every extracted string and identifier is copied with `:binary.copy/1` to prevent
  sub-binary retention of large SSE chunks in long-lived chat/TUI processes.
  """
  @spec parse_symbols(String.t()) :: %{optional(String.t()) => term()}
  def parse_symbols(input) when is_binary(input) do
    ZigNIF.parse_symbols(input)
  end

  @doc """
  Converts an internal `OpenUILang.AST` expression node into the TUI tuple AST format
  (`{component, args}`, `{:ref, name}`, `{:var, "$name"}`, literals, lists, maps).
  """
  @spec ast_to_tuple(map() | term()) :: term()
  def ast_to_tuple(%{k: :comp, name: name, args: args}) do
    {:binary.copy(name), Enum.map(args, &ast_to_tuple/1)}
  end

  def ast_to_tuple(%{k: :ref, n: name}), do: {:ref, :binary.copy(name)}
  def ast_to_tuple(%{k: :state_ref, n: name}), do: {:var, :binary.copy(name)}
  def ast_to_tuple(%{k: :arr, els: els}), do: Enum.map(els, &ast_to_tuple/1)

  def ast_to_tuple(%{k: :obj, entries: entries}) do
    Map.new(entries, fn {k, v} -> {:binary.copy(k), ast_to_tuple(v)} end)
  end

  def ast_to_tuple(%{k: :str, v: v}) when is_binary(v), do: :binary.copy(v)
  def ast_to_tuple(%{k: :num, v: v}), do: v
  def ast_to_tuple(%{k: :bool, v: v}), do: v
  def ast_to_tuple(%{k: :null}), do: nil
  def ast_to_tuple(%{k: :ph, n: n}) when is_binary(n), do: {:unresolved, :binary.copy(n)}
  def ast_to_tuple(%{k: :ph}), do: {:unresolved, "expr"}

  def ast_to_tuple(%{k: :bin_op, op: op, left: l, right: r}) do
    {:bin_op, op, ast_to_tuple(l), ast_to_tuple(r)}
  end

  def ast_to_tuple(%{k: :ternary, cond: c, then: t, else: e}) do
    {:ternary, ast_to_tuple(c), ast_to_tuple(t), ast_to_tuple(e)}
  end

  def ast_to_tuple(%{k: :unary_op, op: "-", operand: %{k: :num, v: n}}), do: -n

  def ast_to_tuple(%{k: :unary_op, op: op, operand: operand}),
    do: {:unary_op, op, ast_to_tuple(operand)}

  def ast_to_tuple(other), do: other

  # ── Streaming Parser ─────────────────────────────────────────────────────

  @spec new_stream_parser(map() | nil, String.t() | nil) :: t()
  def new_stream_parser(cat, root_name \\ nil) do
    %__MODULE__{
      cat: cat,
      root_name: root_name || (cat && Map.get(cat, :root))
    }
  end

  @spec push(t(), String.t(), boolean()) :: {map(), t()}
  def push(%__MODULE__{} = sp, chunk, complete \\ false) when is_binary(chunk) do
    sp = %{sp | buf: sp.buf <> chunk}
    current_result(sp, complete)
  end

  @spec set(t(), String.t(), boolean()) :: {map(), t()}
  def set(%__MODULE__{} = sp, full_text, complete \\ false) when is_binary(full_text) do
    sp =
      if byte_size(full_text) < byte_size(sp.buf) or not String.starts_with?(full_text, sp.buf) do
        reset(sp)
      else
        sp
      end

    delta_len = byte_size(full_text) - byte_size(sp.buf)

    sp =
      if delta_len > 0 do
        delta = binary_part(full_text, byte_size(sp.buf), delta_len)
        %{sp | buf: sp.buf <> delta}
      else
        sp
      end

    current_result(sp, complete)
  end

  @spec get_result(t(), boolean()) :: {map(), t()}
  def get_result(%__MODULE__{} = sp, complete \\ false) do
    current_result(sp, complete)
  end

  defp reset(%__MODULE__{} = sp) do
    %{
      sp
      | buf: "",
        cleaned: "",
        has_fences: false,
        completed_end: 0,
        completed_raw_end: 0,
        completed_stmt_map: %{},
        completed_stmt_order: [],
        completed_count: 0,
        completed_syms: %{},
        completed_unreached: MapSet.new(),
        completed_state_decls: %{},
        completed_Init_state: %{},
        completed_queries: [],
        completed_mutations: [],
        mat_cache: %{},
        rev_deps: %{}
    }
  end

  defp advance_stream(%__MODULE__{} = sp) do
    buf_len = byte_size(sp.buf)
    fence_check_pos = max(0, sp.completed_raw_end - 2)

    newly_fenced? =
      not sp.has_fences and buf_len >= fence_check_pos + 3 and
        :binary.match(sp.buf, "```", scope: {fence_check_pos, buf_len - fence_check_pos}) !=
          :nomatch

    sp =
      cond do
        newly_fenced? and sp.completed_raw_end > 0 ->
          %{reset(sp) | buf: sp.buf, has_fences: true}

        newly_fenced? ->
          %{sp | has_fences: true}

        true ->
          sp
      end

    if not sp.has_fences and buf_len >= sp.completed_raw_end do
      raw_tail = binary_part(sp.buf, sp.completed_raw_end, buf_len - sp.completed_raw_end)
      cleaned_tail = raw_tail |> Statements.strip_comments() |> String.trim_trailing()

      {local_pending_start, sp} =
        do_scan_completed(cleaned_tail, cleaned_tail, 0, 0, 0, 0, false, %{sp | completed_end: 0})

      sp =
        if sp.completed_end > 0 do
          nl_count = count_newlines(binary_part(cleaned_tail, 0, sp.completed_end), 0)
          raw_end = skip_n_newlines(sp.buf, sp.completed_raw_end, buf_len, nl_count)
          %{sp | completed_raw_end: raw_end, completed_end: 0}
        else
          sp
        end

      pending_len = byte_size(cleaned_tail) - local_pending_start
      pending_text = binary_part(cleaned_tail, local_pending_start, pending_len) |> String.trim()
      {pending_text, sp}
    else
      sp = refresh_cleaned_fenced(sp)
      {pending_start, sp} = scan_new_completed(sp)
      len = byte_size(sp.cleaned)
      pending_text = binary_part(sp.cleaned, pending_start, len - pending_start) |> String.trim()
      {pending_text, sp}
    end
  end

  defp refresh_cleaned_fenced(%__MODULE__{} = sp) do
    next = Statements.preprocess(sp.buf) |> :binary.copy()
    prefix = binary_part(sp.cleaned, 0, min(sp.completed_end, byte_size(sp.cleaned)))

    if not String.starts_with?(next, prefix) do
      %{
        sp
        | cleaned: next,
          completed_end: 0,
          completed_raw_end: 0,
          completed_stmt_map: %{},
          completed_stmt_order: [],
          completed_count: 0,
          completed_syms: %{},
          completed_unreached: MapSet.new(),
          completed_state_decls: %{},
          completed_Init_state: %{},
          completed_queries: [],
          completed_mutations: [],
          mat_cache: %{},
          rev_deps: %{}
      }
    else
      %{sp | cleaned: next}
    end
  end

  defp add_completed_stmt(%__MODULE__{} = sp, text) do
    t = String.trim(text)

    if t == "" do
      sp
    else
      stmts = ZigNIF.parse_statements(t, 1)

      Enum.reduce(stmts, sp, fn stmt, acc_sp ->
        s_id = stmt.id

        order =
          if Map.has_key?(acc_sp.completed_stmt_map, s_id) do
            acc_sp.completed_stmt_order
          else
            [s_id | acc_sp.completed_stmt_order]
          end

        sym_ast = if stmt.kind == :state, do: stmt.init, else: stmt.expr
        next_syms = Map.put(acc_sp.completed_syms, s_id, sym_ast)

        next_unreached =
          if stmt.kind in [:state, :query, :mutation] do
            MapSet.delete(acc_sp.completed_unreached, s_id)
          else
            MapSet.put(acc_sp.completed_unreached, s_id)
          end

        next_state_decls =
          Enum.reduce(stmt.state_refs, acc_sp.completed_state_decls, fn dep, st_map ->
            if Map.has_key?(st_map, dep), do: st_map, else: Map.put(st_map, dep, nil)
          end)

        next_init_state =
          if stmt.kind == :state do
            Map.put(acc_sp.completed_Init_state, s_id, stmt)
          else
            Map.delete(acc_sp.completed_Init_state, s_id)
          end

        next_queries =
          if stmt.kind == :query do
            [stmt | Enum.reject(acc_sp.completed_queries, &(&1.id == s_id))]
          else
            Enum.reject(acc_sp.completed_queries, &(&1.id == s_id))
          end

        next_mutations =
          if stmt.kind == :mutation do
            [stmt | Enum.reject(acc_sp.completed_mutations, &(&1.id == s_id))]
          else
            Enum.reject(acc_sp.completed_mutations, &(&1.id == s_id))
          end

        rev_deps = update_rev_deps(acc_sp.rev_deps, s_id, stmt.refs)
        mat_cache = invalidate_dependents(acc_sp.mat_cache, rev_deps, [s_id], MapSet.new([s_id]))

        %{
          acc_sp
          | completed_stmt_map: Map.put(acc_sp.completed_stmt_map, s_id, stmt),
            completed_stmt_order: order,
            completed_count: acc_sp.completed_count + 1,
            completed_syms: next_syms,
            completed_unreached: next_unreached,
            completed_state_decls: next_state_decls,
            completed_Init_state: next_init_state,
            completed_queries: next_queries,
            completed_mutations: next_mutations,
            mat_cache: mat_cache,
            rev_deps: rev_deps
        }
      end)
    end
  end

  defp update_rev_deps(rev_deps, stmt_id, refs) do
    Enum.reduce(refs, rev_deps, fn ref, acc ->
      existing = Map.get(acc, ref, [])
      if stmt_id in existing, do: acc, else: Map.put(acc, ref, [stmt_id | existing])
    end)
  end

  defp invalidate_dependents(cache, _rev_deps, [], _seen), do: cache

  defp invalidate_dependents(cache, rev_deps, [id | rest], seen) do
    cache = Map.delete(cache, {:value, id, true}) |> Map.delete({:value, id, false})
    parents = Map.get(rev_deps, id, [])

    {new_q, new_seen} =
      Enum.reduce(parents, {rest, seen}, fn p, {q, s} ->
        if MapSet.member?(s, p), do: {q, s}, else: {[p | q], MapSet.put(s, p)}
      end)

    invalidate_dependents(cache, rev_deps, new_q, new_seen)
  end

  defp scan_new_completed(%__MODULE__{} = sp) do
    len = byte_size(sp.cleaned)
    start = sp.completed_end
    rest = binary_part(sp.cleaned, start, len - start)
    do_scan_completed(sp.cleaned, rest, start, start, 0, 0, false, sp)
  end

  defp count_newlines(<<>>, n), do: n
  defp count_newlines(<<"\n", rest::binary>>, n), do: count_newlines(rest, n + 1)
  defp count_newlines(<<_c, rest::binary>>, n), do: count_newlines(rest, n)

  defp skip_n_newlines(_buf, pos, _len, 0), do: pos
  defp skip_n_newlines(_buf, pos, len, _n) when pos >= len, do: len

  defp skip_n_newlines(buf, pos, len, n) do
    if :binary.at(buf, pos) == ?\n do
      skip_n_newlines(buf, pos + 1, len, n - 1)
    else
      skip_n_newlines(buf, pos + 1, len, n)
    end
  end

  defp do_scan_completed(_cleaned, <<>>, _i, stmt_start, _depth, _tdepth, _in_str, sp) do
    {stmt_start, sp}
  end

  defp do_scan_completed(cleaned, <<"\\", _esc, rest::binary>>, i, stmt_start, depth, tdepth, in_str, sp)
       when in_str != false do
    do_scan_completed(cleaned, rest, i + 2, stmt_start, depth, tdepth, in_str, sp)
  end

  defp do_scan_completed(cleaned, <<c, rest::binary>>, i, stmt_start, depth, tdepth, in_str, sp)
       when in_str != false do
    next_str = if c == in_str, do: false, else: in_str
    do_scan_completed(cleaned, rest, i + 1, stmt_start, depth, tdepth, next_str, sp)
  end

  defp do_scan_completed(cleaned, <<c, rest::binary>>, i, stmt_start, depth, tdepth, false, sp)
       when c in [?", ?'] do
    do_scan_completed(cleaned, rest, i + 1, stmt_start, depth, tdepth, c, sp)
  end

  defp do_scan_completed(cleaned, <<c, rest::binary>>, i, stmt_start, depth, tdepth, false, sp)
       when c in [?(, ?[, ?{] do
    do_scan_completed(cleaned, rest, i + 1, stmt_start, depth + 1, tdepth, false, sp)
  end

  defp do_scan_completed(cleaned, <<c, rest::binary>>, i, stmt_start, depth, tdepth, false, sp)
       when c in [?), ?], ?}] do
    do_scan_completed(cleaned, rest, i + 1, stmt_start, max(0, depth - 1), tdepth, false, sp)
  end

  defp do_scan_completed(cleaned, <<??, rest::binary>>, i, stmt_start, 0, tdepth, false, sp) do
    do_scan_completed(cleaned, rest, i + 1, stmt_start, 0, tdepth + 1, false, sp)
  end

  defp do_scan_completed(cleaned, <<?:, rest::binary>>, i, stmt_start, 0, tdepth, false, sp)
       when tdepth > 0 do
    do_scan_completed(cleaned, rest, i + 1, stmt_start, 0, tdepth - 1, false, sp)
  end

  defp do_scan_completed(cleaned, <<"\n", rest::binary>>, i, stmt_start, depth, tdepth, false, sp)
       when depth <= 0 and tdepth <= 0 do
    peek_char = peek_next_non_ws_char(rest)

    if peek_char == ?? or (peek_char == ?: and tdepth > 0) do
      do_scan_completed(cleaned, rest, i + 1, stmt_start, depth, tdepth, false, sp)
    else
      slice = binary_part(cleaned, stmt_start, i - stmt_start) |> String.trim()
      sp = if slice != "", do: add_completed_stmt(sp, slice), else: sp
      next_start = i + 1
      sp = %{sp | completed_end: next_start}
      do_scan_completed(cleaned, rest, next_start, next_start, depth, tdepth, false, sp)
    end
  end

  defp do_scan_completed(cleaned, <<_c, rest::binary>>, i, stmt_start, depth, tdepth, false, sp) do
    do_scan_completed(cleaned, rest, i + 1, stmt_start, depth, tdepth, false, sp)
  end

  defp peek_next_non_ws_char(<<>>), do: nil

  defp peek_next_non_ws_char(<<c, rest::binary>>) when c in [?\s, ?\t, ?\r, ?\n] do
    peek_next_non_ws_char(rest)
  end

  defp peek_next_non_ws_char(<<c, _::binary>>), do: c

  defp current_result(%__MODULE__{} = sp, complete) do
    {pending_text, sp} = advance_stream(sp)

    if pending_text == "" do
      if sp.completed_count == 0 do
        {empty_result(), sp}
      else
        non_val_stmts =
          Map.values(sp.completed_Init_state) ++
            Enum.reverse(sp.completed_queries) ++
            Enum.reverse(sp.completed_mutations)

        pre = %{
          syms: sp.completed_syms,
          unreached: sp.completed_unreached,
          base_state_decls: sp.completed_state_decls,
          rev_order: sp.completed_stmt_order,
          non_val_stmts: non_val_stmts,
          pending_ids: nil
        }

        {res, mat_cache} =
          build_result(
            sp.completed_stmt_map,
            nil,
            false,
            sp.completed_count,
            sp.cat,
            sp.root_name,
            nil,
            sp.mat_cache,
            pre
          )

        {res, %{sp | mat_cache: mat_cache}}
      end
    else
      {was_incomplete, stmts} = ZigNIF.parse_pending(pending_text, 1)

      if stmts == [] do
        if sp.completed_count == 0 do
          {empty_result(was_incomplete), sp}
        else
          non_val_stmts =
            Map.values(sp.completed_Init_state) ++
              Enum.reverse(sp.completed_queries) ++
              Enum.reverse(sp.completed_mutations)

          pre = %{
            syms: sp.completed_syms,
            unreached: sp.completed_unreached,
            base_state_decls: sp.completed_state_decls,
            rev_order: sp.completed_stmt_order,
            non_val_stmts: non_val_stmts,
            pending_ids: nil
          }

          {res, mat_cache} =
            build_result(
              sp.completed_stmt_map,
              nil,
              was_incomplete,
              sp.completed_count,
              sp.cat,
              sp.root_name,
              nil,
              sp.mat_cache,
              pre
            )

          {res, %{sp | mat_cache: mat_cache}}
        end
      else
        {all_map, rev_all_order, pending_ids, temp_rev_deps, all_syms, all_unreached, pending_stmts} =
          Enum.reduce(
            stmts,
            {sp.completed_stmt_map, sp.completed_stmt_order, MapSet.new(), sp.rev_deps,
             sp.completed_syms, sp.completed_unreached, []},
            fn stmt, {acc_map, acc_order, acc_pending, acc_rdeps, acc_syms, acc_unr, acc_pstmts} ->
              s_id = stmt.id

              if Map.has_key?(sp.completed_stmt_map, s_id) and was_incomplete do
                {acc_map, acc_order, acc_pending, acc_rdeps, acc_syms, acc_unr, acc_pstmts}
              else
                acc_order =
                  if Map.has_key?(acc_map, s_id), do: acc_order, else: [s_id | acc_order]

                acc_rdeps = update_rev_deps(acc_rdeps, s_id, stmt.refs)
                sym_ast = if stmt.kind == :state, do: stmt.init, else: stmt.expr
                acc_syms = Map.put(acc_syms, s_id, sym_ast)

                acc_unr =
                  if stmt.kind in [:state, :query, :mutation] do
                    MapSet.delete(acc_unr, s_id)
                  else
                    MapSet.put(acc_unr, s_id)
                  end

                {Map.put(acc_map, s_id, stmt), acc_order, MapSet.put(acc_pending, s_id),
                 acc_rdeps, acc_syms, acc_unr, [stmt | acc_pstmts]}
              end
            end
          )

        temp_cache =
          invalidate_dependents(
            sp.mat_cache,
            temp_rev_deps,
            MapSet.to_list(pending_ids),
            pending_ids
          )

        tail_name = detect_partial_state_tail(sp.buf, pending_text, complete)
        partial_ref = if tail_name, do: %{name: tail_name, stmt_ids: pending_ids}, else: nil
        pending_stmts = Enum.reverse(pending_stmts)

        non_val_stmts =
          if Enum.any?(pending_stmts, &(&1.kind in [:state, :query, :mutation])) or
               sp.completed_queries != [] or sp.completed_mutations != [] do
            rev_all_order
            |> Enum.reverse()
            |> Enum.reduce([], fn id, acc ->
              st = Map.fetch!(all_map, id)
              if st.kind in [:state, :query, :mutation], do: [st | acc], else: acc
            end)
            |> Enum.reverse()
          else
            Map.values(sp.completed_Init_state)
          end

        pre = %{
          syms: all_syms,
          unreached: all_unreached,
          base_state_decls: sp.completed_state_decls,
          rev_order: rev_all_order,
          non_val_stmts: non_val_stmts,
          pending_stmts: pending_stmts,
          pending_ids: pending_ids
        }

        {res, next_temp_cache} =
          build_result(
            all_map,
            nil,
            was_incomplete,
            sp.completed_count + length(stmts),
            sp.cat,
            sp.root_name,
            partial_ref,
            temp_cache,
            pre
          )

        {res, %{sp | mat_cache: next_temp_cache}}
      end
    end
  end

  defp detect_partial_state_tail(_buf, _pending_text, true), do: nil

  defp detect_partial_state_tail(buf, pending_text, false) do
    case extract_trailing_state_var(buf) do
      nil ->
        nil

      tail ->
        prefix_len = byte_size(pending_text) - byte_size(tail)

        if String.ends_with?(pending_text, tail) and prefix_len >= 0 do
          before_tail = binary_part(pending_text, 0, prefix_len)

          if not contains_state_token?(before_tail, tail) do
            tail
          else
            nil
          end
        else
          nil
        end
    end
  end

  defp extract_trailing_state_var(buf) do
    len = byte_size(buf)
    if len < 2, do: nil, else: scan_trailing_ident(buf, len - 1, len)
  end

  defp scan_trailing_ident(buf, i, len) when i >= 0 do
    c = :binary.at(buf, i)

    cond do
      c in ?a..?z or c in ?A..?Z or c in ?0..?9 or c == ?_ ->
        if i == 0, do: nil, else: scan_trailing_ident(buf, i - 1, len)

      c == ?$ and i < len - 1 ->
        binary_part(buf, i, len - i)

      true ->
        nil
    end
  end

  defp contains_state_token?(haystack, tail) do
    tlen = byte_size(tail)
    hlen = byte_size(haystack)

    case :binary.matches(haystack, tail) do
      [] ->
        false

      matches ->
        Enum.any?(matches, fn {pos, _} ->
          after_pos = pos + tlen

          if after_pos >= hlen do
            true
          else
            c = :binary.at(haystack, after_pos)
            not (c in ?a..?z or c in ?A..?Z or c in ?0..?9 or c == ?_)
          end
        end)
    end
  end

  # ── Statement Classification & Result Building ───────────────────────────

  defp component_call?(%{k: :comp, name: name} = node) do
    not Map.get(node, :fn, false) and not Builtins.is_builtin?(name) and
      not Builtins.is_reserved_call?(name)
  end

  defp component_call?(_), do: false

  defp pick_entry(stmt_map, typed_stmts, root_name, pre) do
    if Map.has_key?(stmt_map, @default_root_id) do
      %{id: @default_root_id, fallback: false}
    else
      stmts =
        typed_stmts ||
          (pre.rev_order |> Enum.reverse() |> Enum.map(&Map.fetch!(stmt_map, &1)))

      Enum.find_value(stmts, fn stmt ->
        if stmt.kind == :value and component_call?(stmt.expr) and stmt.expr.name == root_name do
          %{id: stmt.id, fallback: true}
        else
          nil
        end
      end)
    end
  end

  defp resolves_to_component_call?(node, syms, seen \\ MapSet.new())
  defp resolves_to_component_call?(nil, _syms, _seen), do: false

  defp resolves_to_component_call?(%{k: :ref, n: n}, syms, seen) do
    if MapSet.member?(seen, n) do
      false
    else
      resolves_to_component_call?(Map.get(syms, n), syms, MapSet.put(seen, n))
    end
  end

  defp resolves_to_component_call?(node, _syms, _seen), do: component_call?(node)

  defp contains_component?(node) do
    AST.any_ast?(node, &component_call?/1)
  end

  defp build_result(
         stmt_map,
         typed_stmts,
         was_incomplete,
         stmt_count,
         cat,
         root_name,
         partial_ref,
         mat_cache,
         pre
       ) do
    entry = pick_entry(stmt_map, typed_stmts, root_name, pre)

    syms =
      if pre != nil do
        pre.syms
      else
        Map.new(stmt_map, fn {id, stmt} ->
          {id, if(stmt.kind == :state, do: stmt.init, else: stmt.expr)}
        end)
      end

    unreached =
      if pre != nil do
        if entry != nil, do: MapSet.delete(pre.unreached, entry.id), else: pre.unreached
      else
        Enum.reduce(typed_stmts, MapSet.new(), fn stmt, acc ->
          cond do
            entry != nil and stmt.id == entry.id -> acc
            stmt.kind in [:state, :query, :mutation] -> acc
            true -> MapSet.put(acc, stmt.id)
          end
        end)
      end

    ctx = %{
      syms: syms,
      cat: cat,
      errors: [],
      unres: [],
      visited: MapSet.new(),
      partial: was_incomplete,
      current_statement_id: entry && entry.id,
      unreached: unreached,
      mat_cache: mat_cache,
      pending_ids: pre && pre[:pending_ids]
    }

    {root, root_expression, ctx} =
      if entry != nil do
        target_ast = Map.fetch!(syms, entry.id)
        {materialized, ctx} = Materialize.materialize_value(target_ast, ctx)

        cond do
          AST.is_element_node?(materialized) ->
            {Map.put(materialized, :statement_id, entry.id), nil, ctx}

          AST.is_ast_node?(materialized) and contains_component?(materialized) ->
            {nil, materialized, ctx}

          true ->
            {nil, nil, ctx}
        end
      else
        {nil, nil, ctx}
      end

    {state_declarations, query_statements, mutation_statements, ctx} =
      extract_statements(typed_stmts, ctx, partial_ref, pre)

    ctx = %{ctx | current_statement_id: entry && entry.id}
    component = root_name || ""

    ctx =
      cond do
        entry == nil ->
          Schema.push_validation_issue(ctx, component, "", %{
            code: "no-root",
            reason: "missing"
          })

        root == nil and root_expression == nil and
            not resolves_to_component_call?(Map.get(syms, entry.id), syms) ->
          Schema.push_validation_issue(ctx, component, "", %{
            code: "no-root",
            reason: "not-component"
          })

        entry.fallback ->
          Schema.push_validation_issue(ctx, component, "", %{
            code: "no-root",
            reason: if(root != nil, do: "fallback", else: "missing")
          })

        true ->
          ctx
      end

    orphaned =
      if entry != nil and MapSet.size(ctx.unreached) > 0 do
        if typed_stmts != nil do
          Enum.reduce(typed_stmts, [], fn stmt, acc ->
            if MapSet.member?(ctx.unreached, stmt.id), do: [stmt.id | acc], else: acc
          end)
          |> Enum.reverse()
        else
          # rev_order is in reverse order, so reducing over rev_order and prepending reverses it back to forward order!
          Enum.reduce(pre.rev_order, [], fn id, acc ->
            if MapSet.member?(ctx.unreached, id), do: [id | acc], else: acc
          end)
        end
      else
        []
      end

    base = %{
      root: root,
      meta: %{
        incomplete: was_incomplete,
        unresolved: Enum.reverse(ctx.unres),
        orphaned: orphaned,
        statement_count: stmt_count,
        errors: Enum.reverse(ctx.errors)
      },
      state_declarations: state_declarations,
      query_statements: query_statements,
      mutation_statements: mutation_statements
    }

    res =
      if root_expression != nil do
        Map.put(base, :root_expression, root_expression)
      else
        base
      end

    {res, ctx.mat_cache}
  end

  defp extract_statements(stmts, ctx, partial_ref, pre) do
    stmts_to_iter = if pre != nil, do: pre.non_val_stmts, else: stmts

    {state_decls, queries, mutations, ctx} =
      Enum.reduce(stmts_to_iter, {%{}, [], [], ctx}, fn stmt, {st_acc, q_acc, m_acc, acc_ctx} ->
        case stmt.kind do
          :state ->
            {val, acc_ctx} = Materialize.materialize_value(stmt.init, acc_ctx)
            {Map.put(st_acc, stmt.id, Schema.strip_keys_meta(val)), q_acc, m_acc, acc_ctx}

          :query ->
            {named_args, acc_ctx} =
              Materialize.name_raw_call_args(stmt.call.args, acc_ctx, stmt.id)

            q_info = %{
              statement_id: stmt.id,
              tool_ast: Enum.at(named_args, 0),
              args_ast: Enum.at(named_args, 1),
              defaults_ast: Enum.at(named_args, 2),
              refresh_ast: Enum.at(named_args, 3),
              deps: Map.get(stmt, :deps),
              complete: true
            }

            {st_acc, q_acc ++ [q_info], m_acc, acc_ctx}

          :mutation ->
            {named_args, acc_ctx} =
              Materialize.name_raw_call_args(stmt.call.args, acc_ctx, stmt.id)

            m_info = %{
              statement_id: stmt.id,
              tool_ast: Enum.at(named_args, 0),
              args_ast: Enum.at(named_args, 1)
            }

            {st_acc, q_acc, m_acc ++ [m_info], acc_ctx}

          :value ->
            {st_acc, q_acc, m_acc, acc_ctx}
        end
      end)

    state_decls =
      if pre != nil and pre[:base_state_decls] != nil do
        merged_base = Map.merge(pre.base_state_decls, state_decls)
        pending_stmts = pre[:pending_stmts] || []

        Enum.reduce(pending_stmts, merged_base, fn stmt, acc_st ->
          deps = Map.get(stmt, :state_refs, [])

          Enum.reduce(deps, acc_st, fn dep, st_map ->
            skip? =
              partial_ref != nil and dep == partial_ref.name and
                MapSet.member?(partial_ref.stmt_ids, stmt.id)

            if skip? or Map.has_key?(st_map, dep) do
              st_map
            else
              Map.put(st_map, dep, nil)
            end
          end)
        end)
      else
        Enum.reduce(stmts, state_decls, fn stmt, acc_st ->
          deps = Map.get(stmt, :state_refs, [])

          Enum.reduce(deps, acc_st, fn dep, st_map ->
            skip? =
              partial_ref != nil and dep == partial_ref.name and
                MapSet.member?(partial_ref.stmt_ids, stmt.id)

            if skip? or Map.has_key?(st_map, dep) do
              st_map
            else
              Map.put(st_map, dep, nil)
            end
          end)
        end)
      end

    {state_decls, queries, mutations, ctx}
  end
end
