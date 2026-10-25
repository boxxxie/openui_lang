defmodule OpenUILang.Rules do
  @moduledoc false

  alias OpenUILang.{Builtins, Schema}

  @numeric_rules MapSet.new(["min", "max", "minLength", "maxLength"])

  @spec parse_rule(String.t()) :: %{type: String.t(), arg: term()}
  def parse_rule(rule) when is_binary(rule) do
    case :binary.match(rule, ":") do
      :nomatch ->
        %{type: rule, arg: nil}

      {idx, 1} ->
        type = binary_part(rule, 0, idx)
        raw_arg = binary_part(rule, idx + 1, byte_size(rule) - idx - 1)

        arg =
          if MapSet.member?(@numeric_rules, type) do
            case Builtins.parse_strict_number(raw_arg) do
              {:ok, n} -> n
              :nan -> raw_arg
            end
          else
            raw_arg
          end

        %{type: type, arg: arg}
    end
  end

  @spec parse_rules(term()) :: [%{type: String.t(), arg: term()}]
  def parse_rules(rules) when is_list(rules) do
    rules
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&parse_rule/1)
  end

  def parse_rules(_), do: []

  @spec parse_structured_rules(term()) :: [%{type: String.t(), arg: term()}]
  def parse_structured_rules(rules) when is_map(rules) and not is_list(rules) do
    keys = Schema.ordered_keys(rules)

    Enum.flat_map(keys, fn key ->
      val = Map.get(rules, key)

      cond do
        val in [false, nil] -> []
        val == true -> [%{type: key, arg: nil}]
        true -> [%{type: key, arg: val}]
      end
    end)
  end

  def parse_structured_rules(_), do: []

  @spec validate(term(), [map()], map()) :: String.t() | nil
  def validate(value, rules, custom_validators \\ %{}) when is_list(rules) do
    Enum.find_value(rules, fn %{type: type} = rule ->
      arg = Map.get(rule, :arg)

      cond do
        is_map(custom_validators) and is_function(Map.get(custom_validators, type), 2) ->
          custom_validators[type].(value, arg)

        true ->
          run_builtin_validator(type, value, arg)
      end
    end)
  end

  defp empty_value?(nil), do: true
  defp empty_value?(""), do: true
  defp empty_value?([]), do: true

  defp empty_value?(%{"value" => inner}) do
    empty_value?(inner)
  end

  defp empty_value?(%{value: inner}) do
    empty_value?(inner)
  end

  defp empty_value?(v) when is_map(v) do
    Map.drop(v, ["__keys__"]) == %{}
  end

  defp empty_value?(_), do: false

  defp run_builtin_validator("required", value, _arg) do
    cond do
      empty_value?(value) ->
        "This field is required"

      is_map(value) ->
        vals = value |> Map.drop(["__keys__"]) |> Map.values()

        if vals != [] and Enum.all?(vals, &is_boolean/1) and not Enum.any?(vals, &(&1 == true)) do
          "At least one option is required"
        else
          nil
        end

      true ->
        nil
    end
  end

  defp run_builtin_validator("email", value, _arg) do
    cond do
      empty_value?(value) ->
        nil

      not is_binary(value) ->
        "Please enter a valid email"

      Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, value) ->
        nil

      true ->
        "Please enter a valid email"
    end
  end

  defp run_builtin_validator("url", value, _arg) do
    cond do
      empty_value?(value) ->
        nil

      not is_binary(value) ->
        "Please enter a valid URL"

      true ->
        uri = URI.parse(value)

        if is_binary(uri.scheme) and uri.scheme != "" and is_binary(uri.host) and uri.host != "" do
          nil
        else
          "Please enter a valid URL"
        end
    end
  end

  defp run_builtin_validator("numeric", value, _arg) do
    cond do
      empty_value?(value) ->
        nil

      is_number(value) ->
        nil

      is_binary(value) and String.trim(value) != "" ->
        case Float.parse(String.trim_leading(value)) do
          {_num, _rest} -> nil
          :error -> "Must be a number"
        end

      true ->
        "Must be a number"
    end
  end

  defp run_builtin_validator("min", value, arg) do
    if empty_value?(value) do
      nil
    else
      case parse_float_like_js(value) do
        {:ok, n} ->
          min_val = Builtins.to_number(arg)
          if n >= min_val, do: nil, else: "Must be at least #{min_val}"

        :error ->
          nil
      end
    end
  end

  defp run_builtin_validator("max", value, arg) do
    if empty_value?(value) do
      nil
    else
      case parse_float_like_js(value) do
        {:ok, n} ->
          max_val = Builtins.to_number(arg)
          if n <= max_val, do: nil, else: "Must be no more than #{max_val}"

        :error ->
          nil
      end
    end
  end

  defp run_builtin_validator("minLength", value, arg) do
    cond do
      empty_value?(value) ->
        nil

      not is_binary(value) ->
        nil

      true ->
        min_len = Builtins.to_number(arg)

        if String.length(value) >= min_len do
          nil
        else
          "Must be at least #{min_len} characters"
        end
    end
  end

  defp run_builtin_validator("maxLength", value, arg) do
    cond do
      empty_value?(value) ->
        nil

      not is_binary(value) ->
        nil

      true ->
        max_len = Builtins.to_number(arg)

        if String.length(value) <= max_len do
          nil
        else
          "Must be no more than #{max_len} characters"
        end
    end
  end

  defp run_builtin_validator("pattern", value, arg) do
    cond do
      empty_value?(value) ->
        nil

      not is_binary(value) or not is_binary(arg) ->
        nil

      true ->
        case Regex.compile(arg) do
          {:ok, regex} ->
            if Regex.match?(regex, value), do: nil, else: "Invalid format"

          {:error, _} ->
            nil
        end
    end
  end

  defp run_builtin_validator(_, _, _), do: nil

  defp parse_float_like_js(v) when is_number(v), do: {:ok, v}

  defp parse_float_like_js(v) when is_binary(v) do
    case Float.parse(String.trim_leading(v)) do
      {n, _} -> {:ok, n}
      :error -> :error
    end
  end

  defp parse_float_like_js(_), do: :error
end
