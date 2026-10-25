defmodule OpenUILang.Parser do
  @moduledoc false

  alias OpenUILang.{Schema, ZigNIF}

  defstruct [
    :cat,
    :root_name,
    :stream_ref,
    mat_cache: %{}
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
    {schema_id, schema_bin} = Schema.zig_schema_args(cat)
    root_str = root_name || (cat && Map.get(cat, :root)) || ""
    ZigNIF.parse_and_materialize(input, schema_id, schema_bin, root_str)
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
    ZigNIF.parse_symbols(input)
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

  # ── Streaming Parser (Backed by Native ZigStreamResource) ────────────────

  @spec new_stream_parser(map() | nil, String.t() | nil) :: t()
  def new_stream_parser(cat, root_name \\ nil) do
    {schema_id, schema_bin} = Schema.zig_schema_args(cat)
    resolved_root = root_name || (cat && Map.get(cat, :root)) || ""
    stream_ref = ZigNIF.stream_new(schema_id, schema_bin, resolved_root)

    %__MODULE__{
      cat: cat,
      root_name: resolved_root,
      stream_ref: stream_ref,
      mat_cache: %{}
    }
  end

  @spec push(t(), String.t(), boolean()) :: {map(), t()}
  def push(%__MODULE__{stream_ref: stream_ref} = sp, chunk, complete \\ false)
      when is_binary(chunk) and is_reference(stream_ref) do
    {res, next_cache} =
      ZigNIF.stream_push(stream_ref, chunk, if(complete, do: 1, else: 0), sp.mat_cache)

    {res, %{sp | mat_cache: next_cache}}
  end

  @spec set(t(), String.t(), boolean()) :: {map(), t()}
  def set(%__MODULE__{stream_ref: stream_ref} = sp, full_text, complete \\ false)
      when is_binary(full_text) and is_reference(stream_ref) do
    {res, next_cache} =
      ZigNIF.stream_set(stream_ref, full_text, if(complete, do: 1, else: 0), sp.mat_cache)

    {res, %{sp | mat_cache: next_cache}}
  end

  @spec get_result(t(), boolean()) :: {map(), t()}
  def get_result(%__MODULE__{stream_ref: stream_ref} = sp, complete \\ false)
      when is_reference(stream_ref) do
    {res, next_cache} = ZigNIF.stream_get(stream_ref, if(complete, do: 1, else: 0), sp.mat_cache)
    {res, %{sp | mat_cache: next_cache}}
  end
end
