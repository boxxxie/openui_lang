defmodule OpenUILang.Lexer do
  @moduledoc false

  @after_value_types [
    :num,
    :str,
    :ident,
    :type,
    :rparen,
    :rbrack,
    true,
    false,
    :null,
    :state_var,
    :builtin_call
  ]

  @type token :: atom() | {atom(), term()}

  @spec tokenize(String.t()) :: [token()]
  def tokenize(src) when is_binary(src) do
    do_tokenize(src, [])
  end

  defp do_tokenize(<<>>, acc) do
    Enum.reverse([:eof | acc])
  end

  # Skip horizontal whitespace (not newlines)
  defp do_tokenize(<<c, rest::binary>>, acc) when c in [?\s, ?\t, ?\r] do
    do_tokenize(rest, acc)
  end

  # Newline
  defp do_tokenize(<<"\n", rest::binary>>, acc) do
    do_tokenize(rest, [:newline | acc])
  end

  # Single-character punctuation
  defp do_tokenize(<<"(", rest::binary>>, acc), do: do_tokenize(rest, [:lparen | acc])
  defp do_tokenize(<<")", rest::binary>>, acc), do: do_tokenize(rest, [:rparen | acc])
  defp do_tokenize(<<"[", rest::binary>>, acc), do: do_tokenize(rest, [:lbrack | acc])
  defp do_tokenize(<<"]", rest::binary>>, acc), do: do_tokenize(rest, [:rbrack | acc])
  defp do_tokenize(<<"{", rest::binary>>, acc), do: do_tokenize(rest, [:lbrace | acc])
  defp do_tokenize(<<"}", rest::binary>>, acc), do: do_tokenize(rest, [:rbrace | acc])
  defp do_tokenize(<<",", rest::binary>>, acc), do: do_tokenize(rest, [:comma | acc])
  defp do_tokenize(<<":", rest::binary>>, acc), do: do_tokenize(rest, [:colon | acc])
  defp do_tokenize(<<".", rest::binary>>, acc), do: do_tokenize(rest, [:dot | acc])
  defp do_tokenize(<<"?", rest::binary>>, acc), do: do_tokenize(rest, [:question | acc])
  defp do_tokenize(<<"+", rest::binary>>, acc), do: do_tokenize(rest, [:plus | acc])
  defp do_tokenize(<<"*", rest::binary>>, acc), do: do_tokenize(rest, [:star | acc])
  defp do_tokenize(<<"/", rest::binary>>, acc), do: do_tokenize(rest, [:slash | acc])
  defp do_tokenize(<<"%", rest::binary>>, acc), do: do_tokenize(rest, [:percent | acc])

  # Two-or-one character operators
  defp do_tokenize(<<"==", rest::binary>>, acc), do: do_tokenize(rest, [:eq_eq | acc])
  defp do_tokenize(<<"=", rest::binary>>, acc), do: do_tokenize(rest, [:equals | acc])
  defp do_tokenize(<<"!=", rest::binary>>, acc), do: do_tokenize(rest, [:not_eq | acc])
  defp do_tokenize(<<"!", rest::binary>>, acc), do: do_tokenize(rest, [:not | acc])
  defp do_tokenize(<<">=", rest::binary>>, acc), do: do_tokenize(rest, [:greater_eq | acc])
  defp do_tokenize(<<">", rest::binary>>, acc), do: do_tokenize(rest, [:greater | acc])
  defp do_tokenize(<<"<=", rest::binary>>, acc), do: do_tokenize(rest, [:less_eq | acc])
  defp do_tokenize(<<"<", rest::binary>>, acc), do: do_tokenize(rest, [:less | acc])
  defp do_tokenize(<<"&&", rest::binary>>, acc), do: do_tokenize(rest, [:and | acc])
  defp do_tokenize(<<"&", rest::binary>>, acc), do: do_tokenize(rest, [:and | acc])
  defp do_tokenize(<<"||", rest::binary>>, acc), do: do_tokenize(rest, [:or | acc])
  defp do_tokenize(<<"|", rest::binary>>, acc), do: do_tokenize(rest, [:or | acc])

  # Double-quoted string literal
  defp do_tokenize(<<"\"", rest::binary>>, acc) do
    {str, remaining} = scan_double_quoted(rest, [])
    do_tokenize(remaining, [{:str, str} | acc])
  end

  # Single-quoted string literal
  defp do_tokenize(<<"'", rest::binary>>, acc) do
    {str, remaining} = scan_single_quoted(rest, [])
    do_tokenize(remaining, [{:str, str} | acc])
  end

  # Minus: negative number literal or subtraction operator
  defp do_tokenize(<<"-", next, _::binary>> = bin, acc) when next in ?0..?9 do
    after_val? =
      case acc do
        [{t, _} | _] when t in @after_value_types -> true
        [t | _] when t in @after_value_types -> true
        _ -> false
      end

    if after_val? do
      <<_, rest::binary>> = bin
      do_tokenize(rest, [:minus | acc])
    else
      {num, rest} = scan_number(bin)
      do_tokenize(rest, [{:num, num} | acc])
    end
  end

  defp do_tokenize(<<"-", rest::binary>>, acc) do
    do_tokenize(rest, [:minus | acc])
  end

  # Positive number literal
  defp do_tokenize(<<c, _::binary>> = bin, acc) when c in ?0..?9 do
    {num, rest} = scan_number(bin)
    do_tokenize(rest, [{:num, num} | acc])
  end

  # State variable: $identifier
  defp do_tokenize(<<"$", c, rest::binary>> = bin, acc)
       when c in ?a..?z or c in ?A..?Z or c == ?_ do
    len = count_ident_bytes(rest, 2)
    ident = :binary.copy(binary_part(bin, 0, len))
    remaining = binary_part(bin, len, byte_size(bin) - len)
    do_tokenize(remaining, [{:state_var, ident} | acc])
  end

  # Builtin / function / action call: @identifier
  defp do_tokenize(<<"@", c, rest::binary>> = bin, acc)
       when c in ?a..?z or c in ?A..?Z or c == ?_ do
    len = count_ident_bytes(rest, 1)
    ident = :binary.copy(binary_part(bin, 1, len))
    remaining = binary_part(bin, len + 1, byte_size(bin) - len - 1)
    do_tokenize(remaining, [{:builtin_call, ident} | acc])
  end

  # Identifiers & keywords
  defp do_tokenize(<<c, rest::binary>> = bin, acc)
       when c in ?a..?z or c in ?A..?Z or c == ?_ do
    len = count_ident_bytes(rest, 1)
    word = :binary.copy(binary_part(bin, 0, len))
    remaining = binary_part(bin, len, byte_size(bin) - len)

    tok =
      case word do
        "true" -> true
        "false" -> false
        "null" -> :null
        _ when c in ?A..?Z -> {:type, word}
        _ -> {:ident, word}
      end

    do_tokenize(remaining, [tok | acc])
  end

  # Skip any other unknown UTF-8 character or byte
  defp do_tokenize(<<_::utf8, rest::binary>>, acc) do
    do_tokenize(rest, acc)
  end

  defp do_tokenize(<<_, rest::binary>>, acc) do
    do_tokenize(rest, acc)
  end

  # ── String scanners ──────────────────────────────────────────────────────

  defp scan_double_quoted(bin, []) do
    scan_double_fast(bin, bin, 0)
  end

  defp scan_double_quoted(<<>>, acc),
    do: {:binary.copy(IO.iodata_to_binary(Enum.reverse(acc))), <<>>}

  defp scan_double_quoted(<<"\"", rest::binary>>, acc),
    do: {:binary.copy(IO.iodata_to_binary(Enum.reverse(acc))), rest}

  defp scan_double_quoted(<<"\\u", h1, h2, h3, h4, rest::binary>>, acc)
       when h1 in ?0..?9 or h1 in ?a..?f or h1 in ?A..?F do
    hex = <<h1, h2, h3, h4>>

    case Integer.parse(hex, 16) do
      {codepoint, ""} ->
        scan_double_quoted(rest, [<<codepoint::utf8>> | acc])

      _ ->
        scan_double_quoted(rest, [<<"\\u", h1, h2, h3, h4>> | acc])
    end
  end

  defp scan_double_quoted(<<"\\", esc, rest::binary>>, acc) do
    unescaped =
      case esc do
        ?" -> "\""
        ?\\ -> "\\"
        ?/ -> "/"
        ?b -> "\b"
        ?f -> "\f"
        ?n -> "\n"
        ?r -> "\r"
        ?t -> "\t"
        other -> <<other>>
      end

    scan_double_quoted(rest, [unescaped | acc])
  end

  defp scan_double_quoted(<<"\\">>, acc) do
    {IO.iodata_to_binary(Enum.reverse(["\\" | acc])), <<>>}
  end

  defp scan_double_quoted(bin, acc) do
    case count_plain_double(bin, 0) do
      0 ->
        <<c, rest::binary>> = bin
        scan_double_quoted(rest, [<<c>> | acc])

      n ->
        chunk = binary_part(bin, 0, n)
        rest = binary_part(bin, n, byte_size(bin) - n)
        scan_double_quoted(rest, [chunk | acc])
    end
  end

  defp scan_double_fast(orig, <<"\"", rest::binary>>, len) do
    {:binary.copy(binary_part(orig, 0, len)), rest}
  end

  defp scan_double_fast(orig, <<>>, len) do
    {:binary.copy(binary_part(orig, 0, len)), <<>>}
  end

  defp scan_double_fast(orig, <<"\\", _::binary>> = rest, len) do
    prefix = if len > 0, do: [binary_part(orig, 0, len)], else: []
    scan_double_quoted(rest, prefix)
  end

  defp scan_double_fast(
         orig,
         <<c1, c2, c3, c4, c5, c6, c7, c8, rest::binary>>,
         len
       )
       when c1 != ?" and c1 != ?\\ and c2 != ?" and c2 != ?\\ and
              c3 != ?" and c3 != ?\\ and c4 != ?" and c4 != ?\\ and
              c5 != ?" and c5 != ?\\ and c6 != ?" and c6 != ?\\ and
              c7 != ?" and c7 != ?\\ and c8 != ?" and c8 != ?\\ do
    scan_double_fast(orig, rest, len + 8)
  end

  defp scan_double_fast(orig, <<_c, rest::binary>>, len) do
    scan_double_fast(orig, rest, len + 1)
  end

  defp count_plain_double(<<c, rest::binary>>, n) when c != ?" and c != ?\\ do
    count_plain_double(rest, n + 1)
  end

  defp count_plain_double(_, n), do: n

  defp scan_single_quoted(bin, []) do
    scan_single_fast(bin, bin, 0)
  end

  defp scan_single_quoted(<<>>, acc),
    do: {:binary.copy(IO.iodata_to_binary(Enum.reverse(acc))), <<>>}

  defp scan_single_quoted(<<"'", rest::binary>>, acc),
    do: {:binary.copy(IO.iodata_to_binary(Enum.reverse(acc))), rest}

  defp scan_single_quoted(<<"\\", esc, rest::binary>>, acc) do
    unescaped =
      case esc do
        ?' -> "'"
        ?\\ -> "\\"
        ?n -> "\n"
        ?t -> "\t"
        other -> <<other>>
      end

    scan_single_quoted(rest, [unescaped | acc])
  end

  defp scan_single_quoted(<<"\\">>, acc) do
    {IO.iodata_to_binary(Enum.reverse(acc)), <<>>}
  end

  defp scan_single_quoted(<<c::utf8, rest::binary>>, acc) do
    scan_single_quoted(rest, [<<c::utf8>> | acc])
  end

  defp scan_single_quoted(<<c, rest::binary>>, acc) do
    scan_single_quoted(rest, [<<c>> | acc])
  end

  defp scan_single_fast(orig, <<"'", rest::binary>>, len) do
    {:binary.copy(binary_part(orig, 0, len)), rest}
  end

  defp scan_single_fast(orig, <<>>, len) do
    {:binary.copy(binary_part(orig, 0, len)), <<>>}
  end

  defp scan_single_fast(orig, <<"\\", _::binary>> = rest, len) do
    prefix = if len > 0, do: [binary_part(orig, 0, len)], else: []
    scan_single_quoted(rest, prefix)
  end

  defp scan_single_fast(orig, <<_c, rest::binary>>, len) do
    scan_single_fast(orig, rest, len + 1)
  end

  # ── Number scanner ───────────────────────────────────────────────────────

  defp scan_number(bin) do
    {sign, rest} =
      case bin do
        <<"-", r::binary>> -> {"-", r}
        r -> {"", r}
      end

    {int_part, rest} = take_digits(rest, "")

    {dec_part, rest} =
      case rest do
        <<".", d, r::binary>> when d in ?0..?9 ->
          {digits, r2} = take_digits(r, <<".", d>>)
          {digits, r2}

        _ ->
          {"", rest}
      end

    {exp_part, rest} =
      case rest do
        <<e, s, r::binary>> when e in [?e, ?E] and s in [?+, ?-] ->
          {digits, r2} = take_digits(r, <<e, s>>)
          {digits, r2}

        <<e, r::binary>> when e in [?e, ?E] ->
          {digits, r2} = take_digits(r, <<e>>)
          {digits, r2}

        _ ->
          {"", rest}
      end

    num_str = sign <> int_part <> dec_part <> exp_part
    num = parse_js_number(num_str, dec_part != "" or exp_part != "")
    apply_unit_suffix(num, rest)
  end

  defp apply_unit_suffix(num, <<u, next, _::binary>> = rest)
       when u in [?k, ?K, ?m, ?M, ?g, ?G, ?b, ?B] and
              (next in ?a..?z or next in ?A..?Z or next in ?0..?9 or next == ?_) do
    {num, rest}
  end

  defp apply_unit_suffix(num, <<u, rest::binary>>) when u in [?k, ?K] do
    {num * 1_000, rest}
  end

  defp apply_unit_suffix(num, <<u, rest::binary>>) when u in [?m, ?M] do
    {num * 1_000_000, rest}
  end

  defp apply_unit_suffix(num, <<u, rest::binary>>) when u in [?g, ?G, ?b, ?B] do
    {num * 1_000_000_000, rest}
  end

  defp apply_unit_suffix(num, rest), do: {num, rest}

  defp parse_js_number(str, true) do
    case Float.parse(str) do
      {f, ""} -> normalize_number(f)
      _ -> 0
    end
  end

  defp parse_js_number(str, false) do
    case Integer.parse(str) do
      {i, ""} -> i
      _ -> 0
    end
  end

  # Normalize whole-number floats like 10.0 to integer 10 so JSON output matches JS
  @spec normalize_number(number()) :: number()
  def normalize_number(n) when is_float(n) do
    trunc_n = trunc(n)
    if n == trunc_n, do: trunc_n, else: n
  end

  def normalize_number(n), do: n

  defp take_digits(bin, prefix) do
    len = count_digit_bytes(bin, 0)
    digits = binary_part(bin, 0, len)
    rest = binary_part(bin, len, byte_size(bin) - len)
    {if(prefix == "", do: digits, else: prefix <> digits), rest}
  end

  defp count_digit_bytes(<<c, rest::binary>>, n) when c in ?0..?9 do
    count_digit_bytes(rest, n + 1)
  end

  defp count_digit_bytes(_, n), do: n

  defp count_ident_bytes(<<c, rest::binary>>, n)
       when c in ?a..?z or c in ?A..?Z or c in ?0..?9 or c == ?_ do
    count_ident_bytes(rest, n + 1)
  end

  defp count_ident_bytes(_, n), do: n
end
