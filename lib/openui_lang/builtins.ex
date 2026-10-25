defmodule OpenUILang.Builtins do
  @moduledoc false

  alias OpenUILang.Lexer

  @builtin_functions %{
    "Count" => %{kind: :function, params: [%{name: "array", required: false}], builtin: true},
    "First" => %{kind: :function, params: [%{name: "array", required: false}], builtin: true},
    "Last" => %{kind: :function, params: [%{name: "array", required: false}], builtin: true},
    "Sum" => %{kind: :function, params: [%{name: "numbers", required: false}], builtin: true},
    "Avg" => %{kind: :function, params: [%{name: "numbers", required: false}], builtin: true},
    "Min" => %{kind: :function, params: [%{name: "numbers", required: false}], builtin: true},
    "Max" => %{kind: :function, params: [%{name: "numbers", required: false}], builtin: true},
    "Sort" => %{
      kind: :function,
      params: [
        %{name: "array", required: false},
        %{name: "field", required: false},
        %{name: "direction", required: false}
      ],
      builtin: true
    },
    "Filter" => %{
      kind: :function,
      params: [
        %{name: "array", required: false},
        %{name: "field", required: false},
        %{name: "operator", required: false},
        %{name: "value", required: false}
      ],
      builtin: true
    },
    "Round" => %{
      kind: :function,
      params: [%{name: "number", required: false}, %{name: "decimals", required: false}],
      builtin: true
    },
    "Abs" => %{kind: :function, params: [%{name: "number", required: false}], builtin: true},
    "Floor" => %{kind: :function, params: [%{name: "number", required: false}], builtin: true},
    "Ceil" => %{kind: :function, params: [%{name: "number", required: false}], builtin: true},
    "Each" => %{
      kind: :function,
      params: [
        %{name: "array", required: false},
        %{name: "varName", required: false},
        %{name: "template", required: false}
      ],
      builtin: true,
      lazy: true
    }
  }

  @builtin_steps %{
    "Run" => %{
      kind: :action,
      params: [%{name: "ref", required: false}],
      builtin: true,
      lazy: true
    },
    "ToAssistant" => %{
      kind: :action,
      params: [%{name: "message", required: false}, %{name: "context", required: false}],
      builtin: true
    },
    "OpenUrl" => %{
      kind: :action,
      params: [%{name: "url", required: false}],
      builtin: true
    },
    "Set" => %{
      kind: :action,
      params: [%{name: "variable", required: false}, %{name: "value", required: false}],
      builtin: true,
      lazy: true
    },
    "Reset" => %{
      kind: :action,
      params: [%{name: "variable", required: false}],
      builtin: true,
      lazy: true
    },
    "Action" => %{
      kind: :action,
      params: [%{name: "steps", required: true}],
      builtin: true,
      lazy: true
    }
  }

  @builtin_calls Map.merge(@builtin_functions, @builtin_steps)

  @reserved_calls MapSet.new(["Query", "Mutation"])

  @spec builtin_calls() :: map()
  def builtin_calls, do: @builtin_calls

  @spec builtin_functions() :: map()
  def builtin_functions, do: @builtin_functions

  @spec builtin_steps() :: map()
  def builtin_steps, do: @builtin_steps

  @spec is_builtin?(String.t()) :: boolean()
  def is_builtin?(name), do: Map.has_key?(@builtin_calls, name)

  @spec is_builtin_function?(String.t()) :: boolean()
  def is_builtin_function?(name), do: Map.has_key?(@builtin_functions, name)

  @spec is_step?(String.t(), map() | nil) :: boolean()
  def is_step?(name, custom_actions \\ nil) do
    Map.has_key?(@builtin_steps, name) or
      (is_map(custom_actions) and Map.has_key?(custom_actions, name))
  end

  @spec is_reserved_call?(String.t()) :: boolean()
  def is_reserved_call?(name), do: MapSet.member?(@reserved_calls, name)

  # ── JS Type Coercion & Equality ──────────────────────────────────────────

  @spec to_number(term()) :: number()
  def to_number(val) when is_number(val), do: Lexer.normalize_number(val)
  def to_number(true), do: 1
  def to_number(false), do: 0

  def to_number(val) when is_binary(val) do
    case parse_strict_number(val) do
      {:ok, n} -> Lexer.normalize_number(n)
      :nan -> 0
    end
  end

  def to_number(_), do: 0

  @spec parse_strict_number(String.t()) :: {:ok, number()} | :nan
  def parse_strict_number(str) when is_binary(str) do
    trimmed = String.trim(str)

    cond do
      trimmed == "" ->
        {:ok, 0}

      Regex.match?(~r/^[+-]?\d+$/, trimmed) ->
        {i, ""} = Integer.parse(trimmed)
        {:ok, i}

      Regex.match?(~r/^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/, trimmed) ->
        # Normalize leading dot like ".5" -> "0.5" or trailing dot "5." -> "5.0" for Float.parse
        norm =
          trimmed
          |> String.replace(~r/^([+-]?)\./, "\\10.")
          |> String.replace(~r/\.$/, ".0")
          |> String.replace(~r/\.([eE])/, ".0\\1")

        case Float.parse(norm) do
          {f, ""} -> {:ok, Lexer.normalize_number(f)}
          _ -> :nan
        end

      true ->
        :nan
    end
  end

  @spec truthy?(term()) :: boolean()
  def truthy?(nil), do: false
  def truthy?(false), do: false
  def truthy?(0), do: false
  def truthy?(+0.0), do: false
  def truthy?(""), do: false
  def truthy?(_), do: true

  @spec loose_equal?(term(), term()) :: boolean()
  def loose_equal?(nil, nil), do: true
  def loose_equal?(nil, _), do: false
  def loose_equal?(_, nil), do: false
  def loose_equal?(a, b) when is_boolean(a), do: loose_equal?(to_number(a), b)
  def loose_equal?(a, b) when is_boolean(b), do: loose_equal?(a, to_number(b))
  def loose_equal?(a, b) when is_number(a) and is_number(b), do: a == b
  def loose_equal?(a, b) when is_binary(a) and is_binary(b), do: a == b

  def loose_equal?(a, b) when is_number(a) and is_binary(b) do
    case parse_strict_number(b) do
      {:ok, nb} -> a == nb
      :nan -> false
    end
  end

  def loose_equal?(a, b) when is_binary(a) and is_number(b) do
    loose_equal?(b, a)
  end

  def loose_equal?(a, b), do: a == b

  @spec to_js_string(term()) :: String.t()
  def to_js_string(nil), do: ""
  def to_js_string(val) when is_binary(val), do: val
  def to_js_string(true), do: "true"
  def to_js_string(false), do: "false"
  def to_js_string(val) when is_integer(val), do: Integer.to_string(val)

  def to_js_string(val) when is_float(val) do
    norm = Lexer.normalize_number(val)
    if is_integer(norm), do: Integer.to_string(norm), else: Float.to_string(norm)
  end

  def to_js_string(val), do: inspect(val)

  # ── Built-in Function Implementations ────────────────────────────────────

  @spec call_builtin(String.t(), map()) :: term()
  def call_builtin("Count", %{"array" => arr}) when is_list(arr), do: length(arr)
  def call_builtin("Count", _), do: 0

  def call_builtin("First", %{"array" => [first | _]}), do: first
  def call_builtin("First", _), do: nil

  def call_builtin("Last", %{"array" => [_ | _] = arr}), do: List.last(arr)
  def call_builtin("Last", _), do: nil

  def call_builtin("Sum", %{"numbers" => arr}) when is_list(arr) do
    arr
    |> Enum.reduce(0, fn x, acc -> acc + to_number(x) end)
    |> Lexer.normalize_number()
  end

  def call_builtin("Sum", _), do: 0

  def call_builtin("Avg", %{"numbers" => [_ | _] = arr}) do
    sum = Enum.reduce(arr, 0, fn x, acc -> acc + to_number(x) end)
    Lexer.normalize_number(sum / length(arr))
  end

  def call_builtin("Avg", _), do: 0

  def call_builtin("Min", %{"numbers" => [first | rest]}) do
    Enum.reduce(rest, to_number(first), fn x, acc -> min(acc, to_number(x)) end)
    |> Lexer.normalize_number()
  end

  def call_builtin("Min", _), do: 0

  def call_builtin("Max", %{"numbers" => [first | rest]}) do
    Enum.reduce(rest, to_number(first), fn x, acc -> max(acc, to_number(x)) end)
    |> Lexer.normalize_number()
  end

  def call_builtin("Max", _), do: 0

  def call_builtin("Sort", args) do
    arr = Map.get(args, "array")

    if not is_list(arr) do
      arr
    else
      field = to_js_string(Map.get(args, "field"))
      desc? = to_js_string(Map.get(args, "direction") || "asc") == "desc"

      Enum.sort(arr, fn a, b ->
        av = if field != "", do: resolve_field(a, field), else: a
        bv = if field != "", do: resolve_field(b, field), else: b
        cmp = compare_sort_values(av, bv)
        if desc?, do: cmp >= 0, else: cmp <= 0
      end)
    end
  end

  def call_builtin("Filter", args) do
    arr = Map.get(args, "array")

    if not is_list(arr) do
      []
    else
      field = to_js_string(Map.get(args, "field"))
      op = to_js_string(Map.get(args, "operator") || "==")
      value = Map.get(args, "value")

      Enum.filter(arr, fn item ->
        v = if field != "", do: resolve_field(item, field), else: item

        case op do
          "==" -> loose_equal?(v, value)
          "!=" -> not loose_equal?(v, value)
          ">" -> to_number(v) > to_number(value)
          "<" -> to_number(v) < to_number(value)
          ">=" -> to_number(v) >= to_number(value)
          "<=" -> to_number(v) <= to_number(value)
          "contains" -> String.contains?(to_js_string(v), to_js_string(value))
          _ -> false
        end
      end)
    end
  end

  def call_builtin("Round", args) do
    num = to_number(Map.get(args, "number"))
    dec_arg = Map.get(args, "decimals")
    d = if dec_arg != nil, do: to_number(dec_arg), else: 0
    factor = :math.pow(10, d)
    # JS Math.round rounds half towards +Infinity: Math.floor(x + 0.5)
    rounded = :math.floor(num * factor + 0.5) / factor
    Lexer.normalize_number(rounded)
  end

  def call_builtin("Abs", args) do
    abs(to_number(Map.get(args, "number"))) |> Lexer.normalize_number()
  end

  def call_builtin("Floor", args) do
    :math.floor(to_number(Map.get(args, "number")) * 1.0) |> trunc()
  end

  def call_builtin("Ceil", args) do
    :math.ceil(to_number(Map.get(args, "number")) * 1.0) |> trunc()
  end

  def call_builtin(_, _), do: nil

  @spec resolve_field(term(), String.t()) :: term()
  def resolve_field(nil, _), do: nil
  def resolve_field(_obj, ""), do: nil

  def resolve_field(obj, path) when is_map(obj) and is_binary(path) do
    parts = String.split(path, ".")

    Enum.reduce_while(parts, obj, fn part, cur ->
      if is_map(cur) do
        {:cont, Map.get(cur, part)}
      else
        {:halt, nil}
      end
    end)
  end

  def resolve_field(_, _), do: nil

  defp compare_sort_values(av, bv) do
    if numeric_value?(av) and numeric_value?(bv) do
      diff = to_number(av) - to_number(bv)

      cond do
        diff < 0 -> -1
        diff > 0 -> 1
        true -> 0
      end
    else
      locale_compare(to_js_string(av), to_js_string(bv))
    end
  end

  defp numeric_value?(v) when is_number(v), do: true

  defp numeric_value?(v) when is_binary(v) and v != "" do
    case parse_strict_number(v) do
      {:ok, _} -> true
      :nan -> false
    end
  end

  defp numeric_value?(_), do: false

  # Reproduce ECMAScript String.prototype.localeCompare() default collation order:
  # Primary: base character (case-insensitive, diacritic-insensitive)
  # Secondary: diacritics (unaccented before accented)
  # Tertiary: case (lowercase before uppercase for identical base/accent)
  @spec locale_compare(String.t(), String.t()) :: -1 | 0 | 1
  def locale_compare(a, b) when a == b, do: 0

  def locale_compare(a, b) do
    ka = collation_key(a)
    kb = collation_key(b)

    cond do
      ka < kb -> -1
      ka > kb -> 1
      true -> 0
    end
  end

  defp collation_key(str) do
    nfd = :unicode.characters_to_nfd_binary(str)
    # Strip combining marks (Unicode category Mn: U+0300..U+036F)
    base = Regex.replace(~r/[\x{0300}-\x{036F}]/u, nfd, "")
    primary = String.downcase(base)
    secondary = String.downcase(str)

    # Tertiary: for each grapheme, 0 if lowercase/other, 1 if uppercase
    tertiary =
      str
      |> String.graphemes()
      |> Enum.map(fn g ->
        if String.upcase(g) == g and String.downcase(g) != g, do: 1, else: 0
      end)

    {primary, secondary, tertiary, str}
  end
end
