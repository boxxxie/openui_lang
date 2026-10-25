defmodule OpenUILang.Message do
  @moduledoc false

  @prefix "]]>openui:"
  @marker ~r/^\]\]>openui:([a-z]+)(?:\?(.*))?$/
  @retry ~r/([^\n])(?=\]\]>openui:content(?:\?|\r?\n|$))/
  @retry_cut ~r/[^\n](\]\]>[a-z:]*)$/

  @spec parse_message(String.t(), keyword()) :: map()
  def parse_message(raw, opts \\ []) when is_binary(raw) do
    streaming? = Keyword.get(opts, :streaming, false)
    text = Regex.replace(@retry, raw, "\\1\n")

    text =
      if streaming? do
        case Regex.run(@retry_cut, text, return: :index) do
          [{full_idx, _}, {cut_idx, cut_len}] ->
            cut_str = binary_part(text, cut_idx, cut_len)

            if String.starts_with?("#{@prefix}content", cut_str) do
              binary_part(text, 0, full_idx + 1)
            else
              text
            end

          _ ->
            text
        end
      else
        text
      end

    lines = String.split(text, "\n")
    last = List.last(lines) || ""

    held? =
      streaming? and last != "" and
        (String.starts_with?(last, @prefix) or String.starts_with?(@prefix, last))

    lines = if held?, do: Enum.slice(lines, 0, length(lines) - 1), else: lines

    initial_sections = [%{kind: nil, attributes: %{}, lines: []}]

    {sections, end_at} =
      lines
      |> Enum.with_index()
      |> Enum.reduce_while({initial_sections, -1}, fn {line, i}, {secs, e_at} ->
        trimmed_cr = String.replace_suffix(line, "\r", "")

        case Regex.run(@marker, trimmed_cr) do
          nil ->
            cur = List.last(secs)
            updated = %{cur | lines: cur.lines ++ [line]}
            {:cont, {List.replace_at(secs, length(secs) - 1, updated), e_at}}

          [_, "end" | _] ->
            secs = close_last_section(secs)
            new_e_at = length(secs) - 1

            if i == length(lines) - 2 and Enum.at(lines, i + 1) == "" do
              {:halt, {secs, new_e_at}}
            else
              {:cont, {secs, new_e_at}}
            end

          [_, kind | rest] ->
            query = List.first(rest) || ""
            secs = close_last_section(secs)
            new_sec = %{kind: kind, attributes: URI.decode_query(query), lines: []}
            {:cont, {secs ++ [new_sec], e_at}}
        end
      end)

    sections = if held?, do: close_last_section(sections), else: sections
    kinds = Enum.map(sections, & &1.kind)
    win = max(0, last_index_of(kinds, "content"))
    ctx_idx = last_index_of(kinds, "context")

    context_raw =
      if ctx_idx > win do
        Enum.at(sections, ctx_idx).lines |> Enum.join("\n")
      else
        nil
      end

    context =
      if is_binary(context_raw) do
        try do
          :json.decode(context_raw)
        rescue
          _ -> context_raw
        end
      else
        nil
      end

    winner = Enum.at(sections, win)

    %{
      content: Enum.join(winner.lines, "\n"),
      context: context,
      attributes: winner.attributes,
      end: end_at >= win
    }
  end

  defp close_last_section(secs) do
    cur = List.last(secs)

    if cur.lines == [] do
      secs
    else
      last_line = List.last(cur.lines) |> String.replace_suffix("\r", "")
      updated_lines = List.replace_at(cur.lines, length(cur.lines) - 1, last_line)
      List.replace_at(secs, length(secs) - 1, %{cur | lines: updated_lines})
    end
  end

  defp last_index_of(list, target) do
    list
    |> Enum.with_index()
    |> Enum.reduce(-1, fn {item, idx}, acc -> if item == target, do: idx, else: acc end)
  end

  @spec build_message(map()) :: String.t()
  def build_message(input) when is_map(input) do
    content = Map.get(input, :content) || Map.get(input, "content") || ""
    context = Map.get(input, :context, Map.get(input, "context"))
    attributes = Map.get(input, :attributes) || Map.get(input, "attributes") || %{}
    end? = Map.get(input, :end, Map.get(input, "end", false))

    query = URI.encode_query(attributes)
    out = "#{@prefix}content#{if query != "", do: "?#{query}", else: ""}\n#{content}"

    out =
      if context != nil do
        ctx_str =
          if is_binary(context), do: context, else: :json.encode(context) |> IO.iodata_to_binary()

        "#{out}\n#{@prefix}context\n#{ctx_str}"
      else
        out
      end

    if end?, do: "#{out}\n#{@prefix}end", else: out
  end
end
