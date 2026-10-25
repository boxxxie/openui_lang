defmodule OpenUILang.Statements do
  @moduledoc false

  alias OpenUILang.ZigNIF

  @spec preprocess(String.t()) :: String.t()
  def preprocess(input) when is_binary(input) do
    ZigNIF.preprocess(input)
  end

  @doc """
  Demultiplexes mixed LLM output containing conversational Markdown prose and
  OpenUI Lang blocks (either fenced in ```` ```openui ```` / ```` ```openui-lang ````
  or starting from `root = ...` / `$var = ...`).

  Returns `%{prose: String.t(), code: String.t()}`.
  """
  @spec demux(String.t()) :: %{prose: String.t(), code: String.t()}
  def demux(input) when is_binary(input) do
    ZigNIF.demux(input)
  end

  @spec strip_fences(String.t()) :: String.t()
  def strip_fences(input) when is_binary(input) do
    if :binary.match(input, "```") == :nomatch do
      input
    else
      blocks = extract_fence_blocks(input, [])

      cond do
        blocks != [] ->
          Enum.join(blocks, "\n")

        String.starts_with?(input, "```") ->
          rest = binary_part(input, 3, byte_size(input) - 3)

          body =
            case :binary.match(rest, "\n") do
              {pos, 1} -> binary_part(rest, pos + 1, byte_size(rest) - pos - 1)
              :nomatch -> rest
            end

          case :binary.matches(body, "```") do
            [] ->
              body

            matches ->
              {last_pos, _} = List.last(matches)
              binary_part(body, 0, last_pos)
          end

        true ->
          input
      end
    end
  end

  defp extract_fence_blocks(<<>>, acc), do: Enum.reverse(acc)

  defp extract_fence_blocks(input, acc) do
    if :binary.match(input, "```") == :nomatch do
      Enum.reverse(acc)
    else
      case find_fence(input, 0, byte_size(input)) do
        :none ->
          Enum.reverse(acc)

        {:ok, fence_start} ->
          after_open = fence_start + 3
          len = byte_size(input)

          case find_newline(input, after_open, len) do
            :none ->
              # Streaming: no newline after opening fence yet
              tail = binary_part(input, after_open, len - after_open)
              cleaned = Regex.replace(~r/^[^\n]*\n?/, tail, "")
              Enum.reverse([cleaned | acc])

            {:ok, nl_pos} ->
              body_start = nl_pos + 1

              case find_fence(input, body_start, len) do
                :none ->
                  block = binary_part(input, body_start, len - body_start)
                  Enum.reverse([block | acc])

                {:ok, close_pos} ->
                  block = binary_part(input, body_start, close_pos - body_start)
                  rest_start = close_pos + 3
                  rest = binary_part(input, rest_start, len - rest_start)
                  extract_fence_blocks(rest, [block | acc])
              end
          end
      end
    end
  end

  defp find_fence(_input, i, len) when i >= len, do: :none

  defp find_fence(input, i, len) do
    case :binary.at(input, i) do
      ?" ->
        next_i = skip_double_quoted(input, i + 1, len)
        find_fence(input, next_i, len)

      ?` when i + 2 < len ->
        if :binary.at(input, i + 1) == ?` and :binary.at(input, i + 2) == ?` do
          {:ok, i}
        else
          find_fence(input, i + 1, len)
        end

      _ ->
        find_fence(input, i + 1, len)
    end
  end

  defp skip_double_quoted(_input, i, len) when i >= len, do: len

  defp skip_double_quoted(input, i, len) do
    case :binary.at(input, i) do
      ?\\ -> skip_double_quoted(input, i + 2, len)
      ?" -> i + 1
      _ -> skip_double_quoted(input, i + 1, len)
    end
  end

  defp find_newline(_input, i, len) when i >= len, do: :none

  defp find_newline(input, i, len) do
    if :binary.at(input, i) == ?\n do
      {:ok, i}
    else
      find_newline(input, i + 1, len)
    end
  end

  @spec strip_comments(String.t()) :: String.t()
  def strip_comments(input) when is_binary(input) do
    if :binary.match(input, ["//", "#"]) == :nomatch do
      input
    else
      ZigNIF.strip_comments(input)
    end
  end

  @spec auto_close(String.t()) :: %{text: String.t(), was_incomplete: boolean()}
  def auto_close(input) when is_binary(input) do
    ZigNIF.auto_close(input)
  end

  @spec split([Lexer.token()]) :: [%{id: String.t(), id_token_type: atom(), tokens: [Lexer.token()]}]
  def split(tokens) when is_list(tokens) do
    do_split(tokens, [])
  end

  defp do_split([], acc), do: Enum.reverse(acc)
  defp do_split([:eof | _], acc), do: Enum.reverse(acc)

  defp do_split([:newline | rest], acc) do
    do_split(rest, acc)
  end

  defp do_split([{t, id}, :equals | rest], acc)
       when t in [:ident, :type, :state_var] do
    {expr_tokens, remaining} = collect_expr_tokens(rest, 0, 0, [])

    acc =
      if expr_tokens != [] do
        [%{id: id, id_token_type: t, tokens: expr_tokens} | acc]
      else
        acc
      end

    do_split(remaining, acc)
  end

  defp do_split([_ | rest], acc) do
    rest_after_line = skip_to_newline(rest)
    do_split(rest_after_line, acc)
  end

  defp skip_to_newline([]), do: []
  defp skip_to_newline([:eof | _] = toks), do: toks
  defp skip_to_newline([:newline | _] = toks), do: toks
  defp skip_to_newline([_ | rest]), do: skip_to_newline(rest)

  defp collect_expr_tokens([], _depth, _tdepth, acc), do: {Enum.reverse(acc), []}

  defp collect_expr_tokens([:eof | _] = toks, _depth, _tdepth, acc) do
    {Enum.reverse(acc), toks}
  end

  defp collect_expr_tokens([:newline | rest] = toks, depth, tdepth, acc) do
    if depth <= 0 and tdepth <= 0 do
      next_t = peek_next_non_newline(rest)

      if next_t == :question or (next_t == :colon and tdepth > 0) do
        collect_expr_tokens(rest, depth, tdepth, acc)
      else
        {Enum.reverse(acc), toks}
      end
    else
      collect_expr_tokens(rest, depth, tdepth, acc)
    end
  end

  defp collect_expr_tokens([tok | rest], depth, tdepth, acc) do
    {new_depth, new_tdepth} =
      cond do
        tok in [:lparen, :lbrack, :lbrace] ->
          {depth + 1, tdepth}

        tok in [:rparen, :rbrack, :rbrace] and depth > 0 ->
          {depth - 1, tdepth}

        tok == :question and depth == 0 ->
          {depth, tdepth + 1}

        tok == :colon and depth == 0 and tdepth > 0 ->
          {depth, tdepth - 1}

        true ->
          {depth, tdepth}
      end

    collect_expr_tokens(rest, new_depth, new_tdepth, [tok | acc])
  end

  defp peek_next_non_newline([]), do: :eof
  defp peek_next_non_newline([:newline | rest]), do: peek_next_non_newline(rest)
  defp peek_next_non_newline([{t, _} | _]), do: t
  defp peek_next_non_newline([t | _]), do: t
end
