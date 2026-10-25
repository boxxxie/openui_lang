defmodule OpenUILang.Parser do
  @moduledoc false

  alias OpenUILang.{AST, Builtins, Expressions, Lexer, Materialize, Schema, Statements}

  @default_root_id "root"

  defstruct [
    :cat,
    :root_name,
    buf: "",
    cleaned: "",
    completed_end: 0,
    completed_stmt_map: %{},
    completed_stmt_order: [],
    completed_count: 0
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
    trimmed = Statements.preprocess(input)

    if trimmed == "" do
      empty_result()
    else
      %{text: text, was_incomplete: was_incomplete} = Statements.auto_close(trimmed)
      stmts = text |> Lexer.tokenize() |> Statements.split()

      if stmts == [] do
        empty_result(was_incomplete)
      else
        {stmt_map, rev_order} =
          Enum.reduce(stmts, {%{}, []}, fn s, {acc_map, acc_order} ->
            expr = Expressions.parse_expression(s.tokens)
            stmt = classify_statement(s, expr)
            acc_order = if Map.has_key?(acc_map, s.id), do: acc_order, else: [s.id | acc_order]
            {Map.put(acc_map, s.id, stmt), acc_order}
          end)

        stmt_order = Enum.reverse(rev_order)
        typed_stmts = Enum.map(stmt_order, &Map.fetch!(stmt_map, &1))

        build_result(
          stmt_map,
          typed_stmts,
          was_incomplete,
          map_size(stmt_map),
          cat,
          root_name,
          nil
        )
      end
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
    trimmed = Statements.preprocess(input)

    if trimmed == "" do
      %{}
    else
      %{text: text} = Statements.auto_close(trimmed)
      stmts = text |> Lexer.tokenize() |> Statements.split()

      Enum.reduce(stmts, %{}, fn s, acc ->
        expr = Expressions.parse_expression(s.tokens)
        Map.put(acc, :binary.copy(s.id), ast_to_tuple(expr))
      end)
    end
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
        completed_end: 0,
        completed_stmt_map: %{},
        completed_stmt_order: [],
        completed_count: 0
    }
  end

  defp refresh_cleaned(%__MODULE__{} = sp) do
    next = Statements.preprocess(sp.buf)
    prefix = binary_part(sp.cleaned, 0, min(sp.completed_end, byte_size(sp.cleaned)))

    if not String.starts_with?(next, prefix) do
      %{
        sp
        | cleaned: next,
          completed_end: 0,
          completed_stmt_map: %{},
          completed_stmt_order: [],
          completed_count: 0
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
      stmts = t |> Lexer.tokenize() |> Statements.split()

      Enum.reduce(stmts, sp, fn s, acc_sp ->
        expr = Expressions.parse_expression(s.tokens)
        stmt = classify_statement(s, expr)

        order =
          if Map.has_key?(acc_sp.completed_stmt_map, s.id) do
            acc_sp.completed_stmt_order
          else
            [s.id | acc_sp.completed_stmt_order]
          end

        %{
          acc_sp
          | completed_stmt_map: Map.put(acc_sp.completed_stmt_map, s.id, stmt),
            completed_stmt_order: order,
            completed_count: acc_sp.completed_count + 1
        }
      end)
    end
  end

  defp scan_new_completed(%__MODULE__{} = sp) do
    len = byte_size(sp.cleaned)
    start = sp.completed_end
    rest = binary_part(sp.cleaned, start, len - start)
    do_scan_completed(sp.cleaned, rest, start, start, 0, 0, false, sp)
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
    sp = refresh_cleaned(sp)
    {pending_start, sp} = scan_new_completed(sp)
    len = byte_size(sp.cleaned)
    pending_text = binary_part(sp.cleaned, pending_start, len - pending_start) |> String.trim()

    if pending_text == "" do
      if sp.completed_count == 0 do
        {empty_result(), sp}
      else
        typed_stmts =
          sp.completed_stmt_order
          |> Enum.reverse()
          |> Enum.map(&Map.fetch!(sp.completed_stmt_map, &1))

        res =
          build_result(
            sp.completed_stmt_map,
            typed_stmts,
            false,
            sp.completed_count,
            sp.cat,
            sp.root_name,
            nil
          )

        {res, sp}
      end
    else
      %{text: closed, was_incomplete: was_incomplete} = Statements.auto_close(pending_text)
      stmts = closed |> Lexer.tokenize() |> Statements.split()

      if stmts == [] do
        if sp.completed_count == 0 do
          {empty_result(was_incomplete), sp}
        else
          typed_stmts =
            sp.completed_stmt_order
            |> Enum.reverse()
            |> Enum.map(&Map.fetch!(sp.completed_stmt_map, &1))

          res =
            build_result(
              sp.completed_stmt_map,
              typed_stmts,
              was_incomplete,
              sp.completed_count,
              sp.cat,
              sp.root_name,
              nil
            )

          {res, sp}
        end
      else
        {all_map, rev_all_order, pending_ids} =
          Enum.reduce(
            stmts,
            {sp.completed_stmt_map, sp.completed_stmt_order, MapSet.new()},
            fn s, {acc_map, acc_order, acc_pending} ->
              if Map.has_key?(sp.completed_stmt_map, s.id) and was_incomplete do
                {acc_map, acc_order, acc_pending}
              else
                expr = Expressions.parse_expression(s.tokens)
                stmt = classify_statement(s, expr)

                acc_order =
                  if Map.has_key?(acc_map, s.id), do: acc_order, else: [s.id | acc_order]

                {Map.put(acc_map, s.id, stmt), acc_order, MapSet.put(acc_pending, s.id)}
              end
            end
          )

        tail_name = detect_partial_state_tail(sp.buf, pending_text, complete)
        partial_ref = if tail_name, do: %{name: tail_name, stmt_ids: pending_ids}, else: nil

        all_typed_stmts =
          rev_all_order
          |> Enum.reverse()
          |> Enum.map(&Map.fetch!(all_map, &1))

        res =
          build_result(
            all_map,
            all_typed_stmts,
            was_incomplete,
            sp.completed_count + length(stmts),
            sp.cat,
            sp.root_name,
            partial_ref
          )

        {res, sp}
      end
    end
  end

  defp detect_partial_state_tail(_buf, _pending_text, true), do: nil

  defp detect_partial_state_tail(buf, pending_text, false) do
    case Regex.run(~r/\$\w+$/, buf) do
      [tail] ->
        prefix_len = byte_size(pending_text) - byte_size(tail)

        if String.ends_with?(pending_text, tail) and prefix_len >= 0 do
          before_tail = binary_part(pending_text, 0, prefix_len)
          escaped = Regex.escape(tail)

          if not Regex.match?(~r/#{escaped}(?!\w)/, before_tail) do
            tail
          else
            nil
          end
        else
          nil
        end

      _ ->
        nil
    end
  end

  # ── Statement Classification & Result Building ───────────────────────────

  defp classify_statement(raw, expr) do
    cond do
      expr.k == :comp and expr.name == "Query" ->
        deps = AST.collect_state_refs(Enum.at(expr.args, 1))
        all_state_refs = Enum.flat_map(expr.args, &AST.collect_state_refs/1)

        stmt = %{
          kind: :query,
          id: raw.id,
          call: %{callee: "Query", args: expr.args},
          expr: expr,
          state_refs: all_state_refs
        }

        if deps != [], do: Map.put(stmt, :deps, deps), else: stmt

      expr.k == :comp and expr.name == "Mutation" ->
        %{
          kind: :mutation,
          id: raw.id,
          call: %{callee: "Mutation", args: expr.args},
          expr: expr,
          state_refs: Enum.flat_map(expr.args, &AST.collect_state_refs/1)
        }

      raw.id_token_type == :state_var ->
        %{
          kind: :state,
          id: raw.id,
          init: expr,
          state_refs: AST.collect_state_refs(expr)
        }

      true ->
        %{
          kind: :value,
          id: raw.id,
          expr: expr,
          state_refs: AST.collect_state_refs(expr)
        }
    end
  end

  defp component_call?(%{k: :comp, name: name} = node) do
    not Map.get(node, :fn, false) and not Builtins.is_builtin?(name) and
      not Builtins.is_reserved_call?(name)
  end

  defp component_call?(_), do: false

  defp pick_entry(stmt_map, typed_stmts, root_name) do
    if Map.has_key?(stmt_map, @default_root_id) do
      %{id: @default_root_id, fallback: false}
    else
      Enum.find_value(typed_stmts, fn stmt ->
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
         partial_ref
       ) do
    entry = pick_entry(stmt_map, typed_stmts, root_name)

    syms =
      Map.new(stmt_map, fn {id, stmt} ->
        {id, if(stmt.kind == :state, do: stmt.init, else: stmt.expr)}
      end)

    unreached =
      Enum.reduce(typed_stmts, MapSet.new(), fn stmt, acc ->
        cond do
          entry != nil and stmt.id == entry.id -> acc
          stmt.kind in [:state, :query, :mutation] -> acc
          true -> MapSet.put(acc, stmt.id)
        end
      end)

    ctx = %{
      syms: syms,
      cat: cat,
      errors: [],
      unres: [],
      visited: MapSet.new(),
      partial: was_incomplete,
      current_statement_id: entry && entry.id,
      unreached: unreached
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
      extract_statements(typed_stmts, ctx, partial_ref)

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
      if entry != nil do
        typed_stmts
        |> Enum.map(& &1.id)
        |> Enum.filter(&MapSet.member?(ctx.unreached, &1))
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

    if root_expression != nil do
      Map.put(base, :root_expression, root_expression)
    else
      base
    end
  end

  defp extract_statements(stmts, ctx, partial_ref) do
    {state_decls, queries, mutations, ctx} =
      Enum.reduce(stmts, {%{}, [], [], ctx}, fn stmt, {st_acc, q_acc, m_acc, acc_ctx} ->
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

    {state_decls, queries, mutations, ctx}
  end
end
