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

  @spec parse_expression([OpenUILang.Lexer.token()]) :: map()
  def parse_expression(tokens) when is_list(tokens) do
    {node, _rest} = parse_expr(tokens, 0)
    node
  end

  defp parse_expr(tokens, min_prec) do
    {left, rest} = parse_prefix(tokens)
    parse_infix_loop(left, rest, min_prec)
  end

  defp parse_infix_loop(left, [tok | _] = tokens, min_prec) do
    prec = infix_prec(tok)

    if prec > min_prec do
      {new_left, rest} = parse_infix(left, tokens)
      parse_infix_loop(new_left, rest, min_prec)
    else
      {left, tokens}
    end
  end

  defp parse_infix_loop(left, [], _min_prec), do: {left, []}

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

  defp parse_prefix([{:str, v} | rest]), do: {%{k: :str, v: v}, rest}
  defp parse_prefix([{:num, v} | rest]), do: {%{k: :num, v: v}, rest}
  defp parse_prefix([true | rest]), do: {%{k: :bool, v: true}, rest}
  defp parse_prefix([false | rest]), do: {%{k: :bool, v: false}, rest}
  defp parse_prefix([:null | rest]), do: {%{k: :null}, rest}

  defp parse_prefix([:lbrack | rest]), do: parse_arr(rest, [])
  defp parse_prefix([:lbrace | rest]), do: parse_obj(rest, [])

  defp parse_prefix([{:state_var, name}, :equals | rest]) do
    {val, rest2} = parse_expr(rest, 0)
    {%{k: :assign, target: name, value: val}, rest2}
  end

  defp parse_prefix([{:state_var, name} | rest]) do
    {%{k: :state_ref, n: name}, rest}
  end

  defp parse_prefix([{:type, name}, :lparen | rest] = tokens) do
    if not Builtins.is_builtin?(name) or name == "Action" do
      {args, rest2} = parse_args(rest, [])
      {%{k: :comp, name: name, args: args}, rest2}
    else
      [_ | tail] = tokens
      {%{k: :ref, n: name}, tail}
    end
  end

  defp parse_prefix([{:type, name} | rest]) do
    {%{k: :ref, n: name}, rest}
  end

  defp parse_prefix([{:builtin_call, name}, :lparen | rest]) do
    {args, rest2} = parse_args(rest, [])
    node = %{k: :comp, name: name, args: args}
    node = if not Builtins.is_builtin?(name), do: Map.put(node, :fn, true), else: node
    {node, rest2}
  end

  defp parse_prefix([{:builtin_call, name} | rest]) do
    {%{k: :ref, n: name}, rest}
  end

  defp parse_prefix([{:ident, name} | rest]) do
    {%{k: :ref, n: name}, rest}
  end

  defp parse_prefix([:not | rest]) do
    {operand, rest2} = parse_expr(rest, @prec_unary)
    {%{k: :unary_op, op: "!", operand: operand}, rest2}
  end

  defp parse_prefix([:minus | rest]) do
    {operand, rest2} = parse_expr(rest, @prec_unary)
    {%{k: :unary_op, op: "-", operand: operand}, rest2}
  end

  defp parse_prefix([:lparen | rest]) do
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

  defp parse_infix(left, [:plus | rest]) do
    {right, rest2} = parse_expr(rest, @prec_add)
    {%{k: :bin_op, op: "+", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [:minus | rest]) do
    {right, rest2} = parse_expr(rest, @prec_add)
    {%{k: :bin_op, op: "-", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [:star | rest]) do
    {right, rest2} = parse_expr(rest, @prec_mul)
    {%{k: :bin_op, op: "*", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [:slash | rest]) do
    {right, rest2} = parse_expr(rest, @prec_mul)
    {%{k: :bin_op, op: "/", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [:percent | rest]) do
    {right, rest2} = parse_expr(rest, @prec_mul)
    {%{k: :bin_op, op: "%", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [:eq_eq | rest]) do
    {right, rest2} = parse_expr(rest, @prec_eq)
    {%{k: :bin_op, op: "==", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [:not_eq | rest]) do
    {right, rest2} = parse_expr(rest, @prec_eq)
    {%{k: :bin_op, op: "!=", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [:greater | rest]) do
    {right, rest2} = parse_expr(rest, @prec_cmp)
    {%{k: :bin_op, op: ">", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [:less | rest]) do
    {right, rest2} = parse_expr(rest, @prec_cmp)
    {%{k: :bin_op, op: "<", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [:greater_eq | rest]) do
    {right, rest2} = parse_expr(rest, @prec_cmp)
    {%{k: :bin_op, op: ">=", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [:less_eq | rest]) do
    {right, rest2} = parse_expr(rest, @prec_cmp)
    {%{k: :bin_op, op: "<=", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [:and | rest]) do
    {right, rest2} = parse_expr(rest, @prec_and)
    {%{k: :bin_op, op: "&&", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [:or | rest]) do
    {right, rest2} = parse_expr(rest, @prec_or)
    {%{k: :bin_op, op: "||", left: left, right: right}, rest2}
  end

  defp parse_infix(left, [:question | rest]) do
    {then_node, rest2} = parse_expr(rest, 0)
    rest3 = eat(rest2, :colon)
    {else_node, rest4} = parse_expr(rest3, 0)
    {%{k: :ternary, cond: left, then: then_node, else: else_node}, rest4}
  end

  defp parse_infix(left, [:dot | rest]) do
    {field, rest2} = parse_key_or_field(rest)
    {%{k: :member, obj: left, field: field}, rest2}
  end

  defp parse_infix(left, [:lbrack | rest]) do
    {index, rest2} = parse_expr(rest, 0)
    rest3 = eat(rest2, :rbrack)
    {%{k: :index, obj: left, index: index}, rest3}
  end

  # ── Compound parsers ─────────────────────────────────────────────────────

  defp parse_args([t | rest], acc) when t in [:rparen, :eof] do
    {Enum.reverse(acc), if(t == :rparen, do: rest, else: [t | rest])}
  end

  defp parse_args([], acc), do: {Enum.reverse(acc), []}

  defp parse_args(tokens, acc) do
    {arg, rest} = parse_expr(tokens, 0)
    rest2 = eat(rest, :comma)
    parse_args(rest2, [arg | acc])
  end

  defp parse_arr([t | rest], acc) when t in [:rbrack, :eof] do
    {%{k: :arr, els: Enum.reverse(acc)}, if(t == :rbrack, do: rest, else: [t | rest])}
  end

  defp parse_arr([], acc), do: {%{k: :arr, els: Enum.reverse(acc)}, []}

  defp parse_arr(tokens, acc) do
    {el, rest} = parse_expr(tokens, 0)
    rest2 = eat(rest, :comma)
    parse_arr(rest2, [el | acc])
  end

  defp parse_obj([t | rest], acc) when t in [:rbrace, :eof] do
    {%{k: :obj, entries: Enum.reverse(acc)}, if(t == :rbrace, do: rest, else: [t | rest])}
  end

  defp parse_obj([], acc), do: {%{k: :obj, entries: Enum.reverse(acc)}, []}

  defp parse_obj(tokens, acc) do
    {key, rest} = parse_key_or_field(tokens)
    rest2 = eat(rest, :colon)
    {val, rest3} = parse_expr(rest2, 0)
    rest4 = eat(rest3, :comma)
    parse_obj(rest4, [{key, val} | acc])
  end

  defp parse_key_or_field([{t, v} | rest]) when t in [:ident, :type, :str, :num] do
    {Builtins.to_js_string(v), rest}
  end

  defp parse_key_or_field([{:state_var, v} | rest]) do
    {String.replace_prefix(v, "$", ""), rest}
  end

  defp parse_key_or_field([_ | rest]) do
    {"?", rest}
  end

  defp parse_key_or_field([]) do
    {"?", []}
  end

  defp eat([kind | rest], kind), do: rest
  defp eat(tokens, _kind), do: tokens
end
