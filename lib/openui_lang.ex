defmodule OpenUILang do
  @moduledoc """
  Elixir implementation of the OpenUI 1.0 Language specification (`openui-lang`).

  Provides a zero-dependency lexer, Pratt expression parser, schema-aware materializer,
  incremental streaming parser, runtime evaluator, statement patch merger, serializer,
  form validation rules, message protocol parser, and system prompt generator.
  """

  alias OpenUILang.{
    Evaluator,
    Expressions,
    Lexer,
    Merge,
    Message,
    Parser,
    Prompt,
    Rules,
    Schema,
    Serialize,
    Statements
  }

  @doc """
  Decodes a JSON string while preserving object key insertion order in `"__keys__"`.
  Required when loading a `LibrarySpec` JSON file so positional argument order matches
  the JSON Schema property order.
  """
  @spec decode_json!(String.t()) :: term()
  def decode_json!(json_bin), do: Schema.decode_json!(json_bin)

  @doc """
  Compiles a decoded `LibrarySpec` (or JSON Schema map) into a compiled catalog (`cat`)
  for use with `parse/3`, `stream_parser/2`, `evaluate_result/2`, and `json_to_openui/3`.
  """
  @spec compile_schema(map() | nil) :: map()
  def compile_schema(schema), do: Schema.compile_schema(schema)

  @doc """
  Parses a complete or partial `openui-lang` source string in one batch pass.
  """
  @spec parse(String.t(), map() | nil, String.t() | nil) :: map()
  def parse(input, compiled_schema \\ nil, root_name \\ nil) do
    Parser.parse(input, compiled_schema, root_name)
  end

  @doc """
  Creates a new stateful `OpenUILang.Parser` streaming parser struct.
  """
  @spec stream_parser(map() | nil, String.t() | nil) :: Parser.t()
  def stream_parser(compiled_schema \\ nil, root_name \\ nil) do
    Parser.new_stream_parser(compiled_schema, root_name)
  end

  @doc """
  Pushes a streamed chunk into the streaming parser and returns `{parse_result, updated_stream_parser}`.
  """
  @spec push_chunk(Parser.t(), String.t(), boolean()) :: {map(), Parser.t()}
  def push_chunk(stream_parser, chunk, complete? \\ false) do
    Parser.push(stream_parser, chunk, complete?)
  end

  @doc """
  Evaluates a `ParseResult` and returns the canonical OpenUI result map
  (`root`, `tree`, `errors`, `errorObjects`, `unresolved`, `orphans`, `incomplete`, `state`).
  """
  @spec evaluate_result(map(), map()) :: map()
  def evaluate_result(parse_result, opts \\ %{}) do
    Evaluator.evaluate_result(parse_result, opts)
  end

  @doc """
  Evaluates a single AST node with the given evaluation context.
  """
  @spec evaluate(map(), map(), map() | nil) :: term()
  def evaluate(ast_node, context, schema_ctx \\ nil) do
    Evaluator.evaluate(ast_node, context, schema_ctx)
  end

  @doc """
  Merges an existing `openui-lang` program with a statement patch and garbage-collects
  statements unreachable from `root_id`.
  """
  @spec merge_statements(String.t(), String.t(), String.t()) :: String.t()
  def merge_statements(existing, patch, root_id \\ "root") do
    Merge.merge_statements(existing, patch, root_id)
  end

  @doc """
  Serializes an `ElementNode` tree back to `openui-lang` source text.
  """
  @spec json_to_openui(map(), map(), map()) :: String.t()
  def json_to_openui(element_node, compiled_schema, options \\ %{}) do
    Serialize.json_to_openui(element_node, compiled_schema, options)
  end

  @doc """
  Validates a form value against structured validation rules.
  Returns `nil` when valid, or an error string when invalid.
  """
  @spec validate_rules(term(), map() | [String.t()], map()) :: String.t() | nil
  def validate_rules(value, rules, custom_validators \\ %{}) do
    parsed =
      if is_list(rules) do
        Rules.parse_rules(rules)
      else
        Rules.parse_structured_rules(rules)
      end

    Rules.validate(value, parsed, custom_validators)
  end

  @doc """
  Parses an OpenUI wire message with `]]>openui:` section markers.
  """
  @spec parse_message(String.t(), keyword()) :: map()
  def parse_message(raw, opts \\ []), do: Message.parse_message(raw, opts)

  @doc """
  Builds an OpenUI wire message with `]]>openui:` section markers.
  """
  @spec build_message(map()) :: String.t()
  def build_message(input), do: Message.build_message(input)

  @doc """
  Generates a system prompt for an LLM from a `LibrarySpec` map.
  """
  @spec generate_system_prompt(map(), keyword()) :: String.t()
  def generate_system_prompt(library_spec, opts \\ []) do
    Prompt.generate_system_prompt(library_spec, opts)
  end

  @doc """
  Tokenizes an `openui-lang` source string into a flat token list.
  """
  @spec tokenize(String.t()) :: [map()]
  def tokenize(src), do: Lexer.tokenize(src)

  @doc """
  Parses a token list into an AST expression node.
  """
  @spec parse_expression([map()]) :: map()
  def parse_expression(tokens), do: Expressions.parse_expression(tokens)

  @doc """
  Auto-closes unclosed strings and brackets in a partial `openui-lang` string.
  """
  @spec auto_close(String.t()) :: %{text: String.t(), was_incomplete: boolean()}
  def auto_close(input), do: Statements.auto_close(input)

  @doc """
  Demultiplexes mixed conversational Markdown prose and `openui-lang` code blocks.
  Returns `%{prose: String.t(), code: String.t()}`.
  """
  @spec demux(String.t()) :: %{prose: String.t(), code: String.t()}
  def demux(input), do: Statements.demux(input)

  @doc """
  Parses an `openui-lang` source string (complete or mid-stream partial) into a flat
  symbol table map `%{"root" => {"Panel", [...]}, "$var" => "default", ...}` for TUI
  forward-reference resolution, 80-column layout clamping, and live `$live_*` bindings.
  """
  @spec parse_symbols(String.t()) :: %{optional(String.t()) => term()}
  def parse_symbols(input), do: Parser.parse_symbols(input)
end
