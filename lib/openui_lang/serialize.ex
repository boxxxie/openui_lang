defmodule OpenUILang.Serialize do
  @moduledoc false

  alias OpenUILang.{AST, Builtins, Schema}

  @precedence %{
    "||" => 2,
    "&&" => 3,
    "==" => 4,
    "!=" => 4,
    ">" => 5,
    "<" => 5,
    ">=" => 5,
    "<=" => 5,
    "+" => 6,
    "-" => 6,
    "*" => 7,
    "/" => 7,
    "%" => 7
  }

  @spec json_to_openui(map(), map(), map()) :: String.t()
  def json_to_openui(element_node, cat, options \\ %{}) do
    collector = %{statements: [], registered: MapSet.new()}
    {root_expr, collector} = serialize_element_expr(element_node, cat, collector)
    root_id = Map.get(element_node, :statement_id) || "root"

    child_lines =
      collector.statements
      |> Enum.reject(&(&1.id == root_id))
      |> Enum.map(& &1.text)

    {state_lines, _collector} =
      case Map.get(options, :state_declarations) do
        decls when is_map(decls) ->
          serialize_state_declarations(decls, cat, collector)

        _ ->
          {[], collector}
      end

    (["#{root_id} = #{root_expr}" | child_lines] ++ state_lines)
    |> Enum.join("\n")
  end

  defp register_stmt(collector, id, text) do
    if MapSet.member?(collector.registered, id) do
      collector
    else
      %{
        collector
        | registered: MapSet.put(collector.registered, id),
          statements: collector.statements ++ [%{id: id, text: text}]
      }
    end
  end

  defp serialize_element_expr(node, cat, collector) do
    comps = if cat, do: cat.components, else: %{}

    case Map.get(comps, node.type_name) do
      %{params: params} ->
        {args, collector} =
          Enum.reduce(params, {[], collector}, fn p, {acc_args, acc_col} ->
            val = Map.get(node.props, p.name)
            {s_val, acc_col} = serialize_value(val, cat, acc_col)
            {acc_args ++ [s_val], acc_col}
          end)

        trimmed_args = trim_trailing_optional_nulls(args, params)
        {"#{node.type_name}(#{Enum.join(trimmed_args, ", ")})", collector}

      nil ->
        keys = Schema.ordered_keys(node.props)

        {args, collector} =
          Enum.reduce(keys, {[], collector}, fn k, {acc_args, acc_col} ->
            {s_val, acc_col} = serialize_value(Map.get(node.props, k), cat, acc_col)
            {acc_args ++ [s_val], acc_col}
          end)

        {"#{node.type_name}(#{Enum.join(args, ", ")})", collector}
    end
  end

  defp trim_trailing_optional_nulls(args, params) do
    if args == [] do
      []
    else
      last = List.last(args)
      param = Enum.at(params, length(args) - 1)

      if last == "null" and param != nil and not param.required do
        trim_trailing_optional_nulls(Enum.slice(args, 0, length(args) - 1), params)
      else
        args
      end
    end
  end

  defp serialize_element_value(node, cat, collector) do
    stmt_id = Map.get(node, :statement_id)

    if is_binary(stmt_id) and stmt_id != "" do
      collector =
        if MapSet.member?(collector.registered, stmt_id) do
          collector
        else
          {expr, collector} = serialize_element_expr(node, cat, collector)
          register_stmt(collector, stmt_id, "#{stmt_id} = #{expr}")
        end

      {stmt_id, collector}
    else
      serialize_element_expr(node, cat, collector)
    end
  end

  defp serialize_value(nil, _cat, collector), do: {"null", collector}

  defp serialize_value(v, _cat, collector) when is_binary(v) do
    {:json.encode(v) |> IO.iodata_to_binary(), collector}
  end

  defp serialize_value(v, _cat, collector) when is_number(v) do
    {Builtins.to_js_string(v), collector}
  end

  defp serialize_value(v, _cat, collector) when is_boolean(v) do
    {if(v, do: "true", else: "false"), collector}
  end

  defp serialize_value(v, cat, collector) when is_list(v) do
    {items, collector} =
      Enum.reduce(v, {[], collector}, fn el, {acc, col} ->
        {s_el, col} = serialize_value(el, cat, col)
        {acc ++ [s_el], col}
      end)

    {"[" <> Enum.join(items, ", ") <> "]", collector}
  end

  defp serialize_value(v, cat, collector) when is_map(v) do
    cond do
      AST.is_element_node?(v) ->
        serialize_element_value(v, cat, collector)

      AST.is_ast_node?(v) ->
        calls = (cat && Map.get(cat, :call_defs)) || Builtins.builtin_calls()
        {serialize_ast_node(v, calls), collector}

      true ->
        keys = Schema.ordered_keys(v)

        {entries, collector} =
          Enum.reduce(keys, {[], collector}, fn k, {acc, col} ->
            {s_val, col} = serialize_value(Map.get(v, k), cat, col)
            {acc ++ ["#{k}: #{s_val}"], col}
          end)

        {"{" <> Enum.join(entries, ", ") <> "}", collector}
    end
  end

  defp serialize_state_declarations(decls, cat, collector) do
    Enum.reduce(decls, {[], collector}, fn {name, val}, {acc_lines, col} ->
      if val == nil do
        {acc_lines, col}
      else
        {s_val, col} = serialize_value(val, cat, col)
        {acc_lines ++ ["#{name} = #{s_val}"], col}
      end
    end)
  end

  defp serialize_ast_node(%{k: :str, v: v}, _calls), do: :json.encode(v) |> IO.iodata_to_binary()
  defp serialize_ast_node(%{k: :num, v: v}, _calls), do: Builtins.to_js_string(v)
  defp serialize_ast_node(%{k: :bool, v: v}, _calls), do: if(v, do: "true", else: "false")
  defp serialize_ast_node(%{k: :null}, _calls), do: "null"
  defp serialize_ast_node(%{k: :ph, n: n}, _calls), do: n
  defp serialize_ast_node(%{k: :state_ref, n: n}, _calls), do: n
  defp serialize_ast_node(%{k: :runtime_ref, n: n}, _calls), do: n
  defp serialize_ast_node(%{k: :ref, n: n}, _calls), do: n

  defp serialize_ast_node(%{k: :arr, els: els}, calls) do
    "[" <> Enum.map_join(els, ", ", &serialize_ast_node(&1, calls)) <> "]"
  end

  defp serialize_ast_node(%{k: :obj, entries: entries}, calls) do
    "{" <>
      Enum.map_join(entries, ", ", fn {k, v} -> "#{k}: #{serialize_ast_node(v, calls)}" end) <>
      "}"
  end

  defp serialize_ast_node(%{k: :bin_op, op: op, left: l, right: r}, calls) do
    left_str = serialize_bin_op_child(l, op, calls)
    right_str = serialize_bin_op_child(r, op, calls)
    "#{left_str} #{op} #{right_str}"
  end

  defp serialize_ast_node(%{k: :unary_op, op: op, operand: operand}, calls) do
    "#{op}#{serialize_ast_node(operand, calls)}"
  end

  defp serialize_ast_node(%{k: :ternary, cond: c, then: t, else: e}, calls) do
    "#{serialize_ast_node(c, calls)} ? #{serialize_ast_node(t, calls)} : #{serialize_ast_node(e, calls)}"
  end

  defp serialize_ast_node(%{k: :member, obj: obj, field: field}, calls) do
    "#{serialize_ast_node(obj, calls)}.#{field}"
  end

  defp serialize_ast_node(%{k: :index, obj: obj, index: idx}, calls) do
    "#{serialize_ast_node(obj, calls)}[#{serialize_ast_node(idx, calls)}]"
  end

  defp serialize_ast_node(%{k: :assign, target: target, value: val}, calls) do
    "#{target} = #{serialize_ast_node(val, calls)}"
  end

  defp serialize_ast_node(%{k: :comp, name: name, args: args}, calls) do
    args_str = Enum.map_join(args, ", ", &serialize_ast_node(&1, calls))

    if Map.has_key?(calls, name) and name != "Action" do
      "@#{name}(#{args_str})"
    else
      "#{name}(#{args_str})"
    end
  end

  defp serialize_ast_node(_, _calls), do: "null"

  defp serialize_bin_op_child(child, parent_op, calls) do
    inner = serialize_ast_node(child, calls)

    if child.k != :bin_op do
      inner
    else
      parent_prec = Map.get(@precedence, parent_op, 0)
      child_prec = Map.get(@precedence, child.op, 0)
      if child_prec < parent_prec, do: "(#{inner})", else: inner
    end
  end
end
