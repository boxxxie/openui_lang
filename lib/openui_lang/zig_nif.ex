defmodule OpenUILang.ZigNIF do
  @moduledoc """
  Native Zig NIF bindings for OpenUI Lang 1.0 lexing, preprocessing,
  auto-closing, Pratt expression parsing, TUI symbol extraction, and statement merging.
  """

  @on_load :load_nif
  @compile {:inline, hydrate_stmt: 1, hydrate_ast: 1, hydrate_bin_op: 1}

  @null_node %{k: :null}
  @true_node %{k: :bool, v: true}
  @false_node %{k: :bool, v: false}

  @doc false
  def load_nif do
    path = :filename.join(:code.priv_dir(:openui_lang), ~c"openui_nif")

    case :erlang.load_nif(path, 0) do
      :ok -> :ok
      {:error, {:reload, _}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec preprocess(String.t()) :: String.t()
  def preprocess(_input), do: :erlang.nif_error(:nif_not_loaded)

  @spec demux(String.t()) :: %{prose: String.t(), code: String.t()}
  def demux(_input), do: :erlang.nif_error(:nif_not_loaded)

  @spec strip_comments(String.t()) :: String.t()
  def strip_comments(_input), do: :erlang.nif_error(:nif_not_loaded)

  @spec auto_close(String.t()) :: %{text: String.t(), was_incomplete: boolean()}
  def auto_close(_input), do: :erlang.nif_error(:nif_not_loaded)

  @spec tokenize(String.t()) :: [OpenUILang.Lexer.token()]
  def tokenize(_input), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def raw_parse_statements(_closed, _need_refs), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def raw_parse_source(_input, _need_refs), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def raw_parse_pending(_pending, _need_refs), do: :erlang.nif_error(:nif_not_loaded)

  @spec parse_statements(String.t(), non_neg_integer()) :: [map()]
  def parse_statements(closed, need_refs) do
    closed
    |> raw_parse_statements(need_refs)
    |> hydrate_stmts()
  end

  @spec parse_source(String.t(), non_neg_integer()) :: :empty | {boolean(), [map()]}
  def parse_source(input, need_refs) do
    case raw_parse_source(input, need_refs) do
      :empty -> :empty
      {was_inc, raw_stmts} -> {was_inc, hydrate_stmts(raw_stmts)}
    end
  end

  @spec parse_pending(String.t(), non_neg_integer()) :: {boolean(), [map()]}
  def parse_pending(pending, need_refs) do
    {was_inc, raw_stmts} = raw_parse_pending(pending, need_refs)
    {was_inc, hydrate_stmts(raw_stmts)}
  end

  @spec parse_symbols(String.t()) :: %{optional(String.t()) => term()}
  def parse_symbols(_input), do: :erlang.nif_error(:nif_not_loaded)

  @spec parse_merge_statements(String.t(), non_neg_integer()) :: [
          {String.t(), String.t(), boolean(), boolean(), [String.t()]}
        ]
  def parse_merge_statements(_input, _strip_fences), do: :erlang.nif_error(:nif_not_loaded)

  @spec register_schema(non_neg_integer(), binary()) :: :ok
  def register_schema(_schema_id, _schema_bin), do: :erlang.nif_error(:nif_not_loaded)

  @spec parse_and_materialize(String.t(), non_neg_integer(), binary(), String.t()) :: map()
  def parse_and_materialize(_input, _schema_id, _schema_bin, _root_name),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec stream_new(non_neg_integer(), binary(), String.t()) :: reference()
  def stream_new(_schema_id, _schema_bin, _root_name), do: :erlang.nif_error(:nif_not_loaded)

  @spec stream_reset(reference()) :: :ok
  def stream_reset(_stream_ref), do: :erlang.nif_error(:nif_not_loaded)

  @spec stream_push(reference(), String.t(), non_neg_integer(), map()) :: {map(), map()}
  def stream_push(_stream_ref, _chunk, _complete, _beam_mat_cache),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec stream_set(reference(), String.t(), non_neg_integer(), map()) :: {map(), map()}
  def stream_set(_stream_ref, _full_text, _complete, _beam_mat_cache),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec stream_get(reference(), non_neg_integer(), map()) :: {map(), map()}
  def stream_get(_stream_ref, _complete, _beam_mat_cache),
    do: :erlang.nif_error(:nif_not_loaded)

  # ── BEAM Literal-Pool Map Hydration ──────────────────────────────────────
  # Hydrating compact NIF tuples into Elixir map literals ensures that every map shares
  # the BEAM module literal pool's constant key tuple (0 heap words allocated for keys,
  # 0 GC copying of key tuples, and 0 C qsort calls).

  defp hydrate_stmts([]), do: []
  defp hydrate_stmts([s | rest]), do: [hydrate_stmt(s) | hydrate_stmts(rest)]

  defp hydrate_stmt({:value, id, expr, state_refs, refs}) do
    %{kind: :value, id: id, expr: hydrate_ast(expr), state_refs: state_refs, refs: refs}
  end

  defp hydrate_stmt({:state, id, init, state_refs, refs}) do
    %{kind: :state, id: id, init: hydrate_ast(init), state_refs: state_refs, refs: refs}
  end

  defp hydrate_stmt({:mutation, id, expr, state_refs, refs}) do
    expr_map = hydrate_ast(expr)

    %{
      kind: :mutation,
      id: id,
      call: %{callee: "Mutation", args: expr_map.args},
      expr: expr_map,
      state_refs: state_refs,
      refs: refs
    }
  end

  defp hydrate_stmt({:query, id, expr, {state_refs, deps}, refs}) do
    expr_map = hydrate_ast(expr)

    %{
      kind: :query,
      id: id,
      call: %{callee: "Query", args: expr_map.args},
      expr: expr_map,
      state_refs: state_refs,
      refs: refs,
      deps: deps
    }
  end

  defp hydrate_stmt({:query, id, expr, state_refs, refs}) do
    expr_map = hydrate_ast(expr)

    %{
      kind: :query,
      id: id,
      call: %{callee: "Query", args: expr_map.args},
      expr: expr_map,
      state_refs: state_refs,
      refs: refs
    }
  end

  defp hydrate_ast({:str, v}), do: %{k: :str, v: v}
  defp hydrate_ast({:num, v}), do: %{k: :num, v: v}
  defp hydrate_ast(true), do: @true_node
  defp hydrate_ast(false), do: @false_node
  defp hydrate_ast(:null), do: @null_node
  defp hydrate_ast({:ref, n}), do: %{k: :ref, n: n}
  defp hydrate_ast({:state_ref, n}), do: %{k: :state_ref, n: n}
  defp hydrate_ast({:comp, name, args}), do: %{k: :comp, name: name, args: hydrate_list(args)}

  defp hydrate_ast({:comp, name, args, true}),
    do: %{k: :comp, name: name, args: hydrate_list(args), fn: true}

  defp hydrate_ast({:arr, els}), do: %{k: :arr, els: hydrate_list(els)}
  defp hydrate_ast({:obj, entries}), do: %{k: :obj, entries: hydrate_entries(entries)}

  defp hydrate_ast({:bin_op, op_atom, l, r}) do
    %{k: :bin_op, op: hydrate_bin_op(op_atom), left: hydrate_ast(l), right: hydrate_ast(r)}
  end

  defp hydrate_ast({:unary_op, :not, operand}) do
    %{k: :unary_op, op: "!", operand: hydrate_ast(operand)}
  end

  defp hydrate_ast({:unary_op, :minus, operand}) do
    %{k: :unary_op, op: "-", operand: hydrate_ast(operand)}
  end

  defp hydrate_ast({:ternary, c, t, e}) do
    %{k: :ternary, cond: hydrate_ast(c), then: hydrate_ast(t), else: hydrate_ast(e)}
  end

  defp hydrate_ast({:member, obj, field}) do
    %{k: :member, obj: hydrate_ast(obj), field: field}
  end

  defp hydrate_ast({:index, obj, idx}) do
    %{k: :index, obj: hydrate_ast(obj), index: hydrate_ast(idx)}
  end

  defp hydrate_ast({:assign, target, val}) do
    %{k: :assign, target: target, value: hydrate_ast(val)}
  end

  defp hydrate_list([]), do: []
  defp hydrate_list([h | t]), do: [hydrate_ast(h) | hydrate_list(t)]

  defp hydrate_entries([]), do: []
  defp hydrate_entries([{k, v} | t]), do: [{k, hydrate_ast(v)} | hydrate_entries(t)]

  defp hydrate_bin_op(:plus), do: "+"
  defp hydrate_bin_op(:minus), do: "-"
  defp hydrate_bin_op(:star), do: "*"
  defp hydrate_bin_op(:slash), do: "/"
  defp hydrate_bin_op(:percent), do: "%"
  defp hydrate_bin_op(:eq_eq), do: "=="
  defp hydrate_bin_op(:not_eq), do: "!="
  defp hydrate_bin_op(:greater), do: ">"
  defp hydrate_bin_op(:less), do: "<"
  defp hydrate_bin_op(:greater_eq), do: ">="
  defp hydrate_bin_op(:less_eq), do: "<="
  defp hydrate_bin_op(:and), do: "&&"
  defp hydrate_bin_op(:or), do: "||"
end
