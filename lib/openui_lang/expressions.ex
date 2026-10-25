defmodule OpenUILang.Expressions do
  @moduledoc false

  alias OpenUILang.Builtins

  @prec_ternary 1
  @prec_or 2
  @prec_and 3
  @prec_eq 4
  @prec_cmp 5
  @prec_add 6
  @prec_mul 7
  @prec_unary 8
  @prec_member 9

  @spec parse_expression([map()]) :: map()
  def parse_expression(tokens) when is_list(tokens) do
    {node, _rest} = parse_expr(tokens, 0)
    node
  end

  defp parse_expr(tokens, min_prec) do
    {left, rest} = parse_prefix(tokens)
    parse_infix_loop(left, rest, min_prec)
  end

  defp parse_infix_loop(left, tokens, min_prec) do
    tok = cur(tokens)
    prec = infix_prec(tok.t)

    if prec > min_prec do
      {new_left, rest} = parse_infix(left, tokens)
      parse_infix_loop(new_left, rest, min_prec)
    else
      {left, tokens}
    end
  end

  defp infix_prec(:question), do: @prec_ternary
  defp infix_prec(:or), do: @prec_or
  defp infix_prec(:and), do: @prec_and
  defp infix_prec(:eq_eq), do: @prec_eq
  defp infix_prec(:not_eq), do: @prec_eq
  defp infix_prec(:greater), do: @prec_cmp
  defp infix_prec(:less), do: @prec_cmp
  defp infix_prec(:greater_eq), do: @prec_cmp
  defp infix_prec(:less_eq), do: @prec_cmp
  defp infix_prec(:plus), do: @prec_add
  defp infix_prec(:minus), do: @prec_add
  defp infix_prec(:star), do: @prec_mul
  defp infix_prec(:slash), do: @prec_mul
  defp infix_prec(:percent), do: @prec_mul
  defp infix_prec(:dot), do: @prec_member
  defp infix_prec(:lbrack), do: @prec_member
  defp infix_prec(_), do: 0

  # ── Prefix / atoms ───────────────────────────────────────────────────────

  defp parse_prefix([%{t: :str, v: v} | rest]), do: {%{k: :str, v: v}, rest}
  defp parse_prefix([%{t: :num, v: v} | rest]), do: {%{k: :num, v: v}, rest}
  defp parse_prefix([%{t: true} | rest]), do: {%{k: :bool, v: true}, rest}
  defp parse_prefix([%{t: false} | rest]), do: {%{k: :bool, v: false}, rest}
  defp parse_prefix([%{t: :null} | rest]), do: {%{k: :null}, rest}

  defp parse_prefix([%{t: :lbrack} | rest]), do: parse_arr(rest, [])
  defp parse_prefix([%{t: :lbrace} | rest]), do: parse_obj(rest, [])

  defp parse_prefix([%{t: :state_var, v: name}, %{t: :equals} | rest]) do
    {val, rest2} = parse_expr(rest, 0)
    {%{k: :assign, target: name, value: val}, rest2}
  end

  defp parse_prefix([%{t: :state_var, v: name} | rest]) do
    {%{k: :state_ref, n: name}, rest}
  end

  defp parse_prefix([%{t: :type, v: name}, %{t: :lparen} | rest] = tokens) do
    if not Builtins.is_builtin?(name) or name == "Action" do
      {args, rest2} = parse_args(rest, [])
      {%{k: :comp, name: name, args: args}, rest2}
    else
      [_ | tail] = tokens
      {%{k: :ref, n: name}, tail}
    end
  end

  defp parse_prefix([%{t: :type, v: name} | rest]) do
    {%{k: :ref, n: name}, rest}
  end

  defp parse_prefix([%{t: :builtin_call, v: name}, %{t: :lparen} | rest]) do
    {args, rest2} = parse_args(rest, [])
    node = %{k: :comp, name: name, args: args}
    node = if not Builtins.is_builtin?(name), do: Map.put(node, :fn, true), else: node
    {node, rest2}
  end

  defp parse_prefix([%{t: :builtin_call, v: name} | rest]) do
    {%{k: :ref, n: name}, rest}
  end

  defp parse_prefix([%{t: :ident, v: name} | rest]) do
    {%{k: :ref, n: name}, rest}
  end

  defp parse_prefix([%{t: :not} | rest]) do
    {operand, rest2} = parse_expr(rest, @prec_unary)
    {%{k: :unary_op, op: "!", operand: operand}, rest2}
  end

  defp parse_prefix([%{t: :minus} | rest]) do
    {operand, rest2} = parse_expr(rest, @prec_unary)
    {%{k: :unary_op, op: "-", operand: operand}, rest2}
  end

  defp parse_prefix([%{t: :lparen} | rest]) do
    {inner, rest2} = parse_expr(rest, 0)
    rest3 = eat(rest2, :rparen)
    {inner, rest3}
  end

  defp parse_prefix([_ | rest]) do
    {%{k: :null}, rest}
  end

  defp parse_prefix([]) do
    {%{k: :null}, []}
  end

  # ── Infix / postfix ──────────────────────────────────────────────────────

  defp parse_infix(left, [%{t: :plus} | rest]) do
    {right, rest2} = parse_expr(rest, @prec_add)
    {%{k: :bin_op, op: "+", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [%{t: :minus} | rest]) do
    {right, rest2} = parse_expr(rest, @prec_add)
    {%{k: :bin_op, op: "-", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [%{t: :star} | rest]) do
    {right, rest2} = parse_expr(rest, @prec_mul)
    {%{k: :bin_op, op: "*", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [%{t: :slash} | rest]) do
    {right, rest2} = parse_expr(rest, @prec_mul)
    {%{k: :bin_op, op: "/", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [%{t: :percent} | rest]) do
    {right, rest2} = parse_expr(rest, @prec_mul)
    {%{k: :bin_op, op: "%", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [%{t: :eq_eq} | rest]) do
    {right, rest2} = parse_expr(rest, @prec_eq)
    {%{k: :bin_op, op: "==", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [%{t: :not_eq} | rest]) do
    {right, rest2} = parse_expr(rest, @prec_eq)
    {%{k: :bin_op, op: "!=", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [%{t: :greater} | rest]) do
    {right, rest2} = parse_expr(rest, @prec_cmp)
    {%{k: :bin_op, op: ">", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [%{t: :less} | rest]) do
    {right, rest2} = parse_expr(rest, @prec_cmp)
    {%{k: :bin_op, op: "<", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [%{t: :greater_eq} | rest]) do
    {right, rest2} = parse_expr(rest, @prec_cmp)
    {%{k: :bin_op, op: ">=", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [%{t: :less_eq} | rest]) do
    {right, rest2} = parse_expr(rest, @prec_cmp)
    {%{k: :bin_op, op: "<=", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [%{t: :and} | rest]) do
    {right, rest2} = parse_expr(rest, @prec_and)
    {%{k: :bin_op, op: "&&", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [%{t: :or} | rest]) do
    {right, rest2} = parse_expr(rest, @prec_or)
    {%{k: :bin_op, op: "||", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [%{t: :question} | rest]) do
    {then_node, rest2} = parse_expr(rest, 0)
    rest3 = eat(rest2, :colon)
    {else_node, rest4} = parse_expr(rest3, 0)
    {%{k: :ternary, cond: left, then: then_node, else: else_node}, rest4}
  end

  defp parse_infix(left, [%{t: :dot} | rest]) do
    {field, rest2} = parse_key_or_field(rest)
    {%{k: :member, obj: left, field: field}, rest2}
  end

  defp parse_infix(left, [%{t: :lbrack} | rest]) do
    {index, rest2} = parse_expr(rest, 0)
    rest3 = eat(rest2, :rbrack)
    {%{k: :index, obj: left, index: index}, rest3}
  end

  # ── Compound parsers ─────────────────────────────────────────────────────

  defp parse_args(tokens, acc) do
    case cur(tokens) do
      %{t: t} when t in [:rparen, :eof] ->
        {Enum.reverse(acc), eat(tokens, :rparen)}

      _ ->
        {arg, rest} = parse_expr(tokens, 0)
        rest2 = eat(rest, :comma)
        parse_args(rest2, [arg | acc])
    end
  end

  defp parse_arr(tokens, acc) do
    case cur(tokens) do
      %{t: t} when t in [:rbrack, :eof] ->
        {%{k: :arr, els: Enum.reverse(acc)}, eat(tokens, :rbrack)}

      _ ->
        {el, rest} = parse_expr(tokens, 0)
        rest2 = eat(rest, :comma)
        parse_arr(rest2, [el | acc])
    end
  end

  defp parse_obj(tokens, acc) do
    case cur(tokens) do
      %{t: t} when t in [:rbrace, :eof] ->
        {%{k: :obj, entries: Enum.reverse(acc)}, eat(tokens, :rbrace)}

      _ ->
        {key, rest} = parse_key_or_field(tokens)
        rest2 = eat(rest, :colon)
        {val, rest3} = parse_expr(rest2, 0)
        rest4 = eat(rest3, :comma)
        parse_obj(rest4, [{key, val} | acc])
    end
  end

  defp parse_key_or_field([%{t: t, v: v} | rest]) when t in [:ident, :type, :str, :num] do
    {Builtins.to_js_string(v), rest}
  end

  defp parse_key_or_field([%{t: :state_var, v: v} | rest]) do
    {String.replace_prefix(v, "$", ""), rest}
  end

  defp parse_key_or_field([_ | rest]) do
    {"?", rest}
  end

  defp parse_key_or_field([]) do
    {"?", []}
  end

  defp cur([tok | _]), do: tok
  defp cur([]), do: %{t: :eof}

  defp eat([%{t: kind} | rest], kind), do: rest
  defp eat(tokens, _kind), do: tokens
end
