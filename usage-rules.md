# OpenUILang Usage Rules

Rules for LLMs and developers working with the `openui_lang` library (OpenUI Lang 1.0 specification in Elixir).

## Core Principles

- **Always preserve JSON Schema property order when decoding schemas:** Positional arguments in OpenUI Lang (`Card("Title", [Text("Body")])`) bind to JSON Schema `properties` in exact document key insertion order. Because Elixir maps (`%{}`) do not preserve key insertion order, always decode raw JSON schemas with `OpenUILang.decode_json!/1` before calling `OpenUILang.compile_schema/1`.
- **Compile schemas once:** Call `OpenUILang.compile_schema/1` once at startup or compile time and reuse the compiled schema map across `OpenUILang.parse/2`, `OpenUILang.create_streaming_parser/1`, `OpenUILang.evaluate_result/2`, `OpenUILang.json_to_openui/2`, and `OpenUILang.generate_prompt/1`.
- **Distinguish parse-time materialization from runtime evaluation:**
  - `OpenUILang.parse/2` returns an un-evaluated materialized tree (`result.root`) plus AST tables (`query_statements`, `mutation_statements`, `state_declarations`) and validation diagnostics (`meta.errors`, `meta.unresolved`, `meta.orphans`, `meta.statement_count`).
  - `OpenUILang.evaluate_result/2` or `OpenUILang.evaluate_root/2` evaluates runtime expressions, reactive `$state` bindings, `@Each` / `@Filter` / `@Sort` builtins, custom functions, and action plans (`@ToAssistant`, `@OpenUrl`, `@Set`, `@Reset`, `@Run`, `@Sequence`).

## Preferred Patterns

### 1. One-Shot Parsing & Evaluation

```elixir
schema =
  File.read!("library.json")
  |> OpenUILang.decode_json!()
  |> OpenUILang.compile_schema()

parse_result = OpenUILang.parse(openui_code, schema)

evaluated =
  OpenUILang.evaluate_result(parse_result, %{
    cat: schema,
    functions: %{
      "Upper" => fn %{"text" => text} -> String.upcase(to_string(text || "")) end
    }
  })

evaluated["root"]         # Canonical evaluated element tree (%{"type" => ..., "props" => ...})
evaluated["state"]        # Declared and inferred reactive $state map
evaluated["errors"]       # Simplified error diagnostics
evaluated["errorObjects"] # Detailed error objects with source/code/component/path/hint
```

### 2. Incremental Streaming from LLM Chunks

Use `OpenUILang.create_streaming_parser/1` and `OpenUILang.push_chunk/2` when streaming tokens from an LLM so the TUI or UI can re-render progressively on every chunk:

```elixir
parser = OpenUILang.create_streaming_parser(schema)

{parser, parse_result} = OpenUILang.push_chunk(parser, chunk)
evaluated = OpenUILang.evaluate_result(parse_result, %{cat: schema})
```

### 3. Statement-Level Patching (`merge_statements/2`)

When an LLM emits incremental statement replacements instead of regenerating the full UI program, merge the patch into the base program before parsing:

```elixir
merged_code = OpenUILang.merge_statements(existing_openui_code, patch_openui_code)
parse_result = OpenUILang.parse(merged_code, schema)
```

### 4. Demultiplexing Prose & Flat Symbol Tables for Fixed-Width TUIs

When streaming mixed conversational Markdown and OpenUI Lang blocks into a fixed-width Terminal UI:

```elixir
{prose_markdown, openui_code} = OpenUILang.demux(stream_buffer)
{:ok, symbols} = OpenUILang.parse_symbols(openui_code)
# symbols["root"] => {"Panel", ["Cluster Health", [{:ref, "kpis"}]]}
```

### 5. Generating LLM System Prompts (`generate_prompt/1`)

Generate an OpenUI 1.0 system prompt directly from a prompt specification or library JSON schema:

```elixir
prompt_text = OpenUILang.generate_prompt(library_spec)
```

## Avoid

- **Do NOT use `:json.decode/1` or `Jason.decode!/1` directly on JSON Schemas with multi-argument components** unless you supply `"__keys__"` ordering metadata inside `"properties"` maps, or use `OpenUILang.decode_json!/1`.
- **Do NOT mutate internal AST nodes directly:** Use `OpenUILang.AST` constructors and `OpenUILang.Serializer.json_to_openui/2` for round-trip serialization.
