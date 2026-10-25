# OpenUILang (`openui_lang`)

**Zero-dependency Elixir parser, streaming engine, runtime evaluator, schema validator, and prompt generator for the [OpenUI 1.0 Language (`openui-lang`)](https://openui.com).**

`OpenUILang` compiles a declarative UI component catalog into a fast, zero-dependency parser and evaluator capable of turning streaming LLM tokens (`root = Dashboard(...)`) into validated, reactive component trees at ~50% fewer tokens than equivalent JSON.

Used as the core language engine for **[`openui_tui`](https://github.com/boxxxie/openui_tui)** (OpenUI TUI Maker & Studio for Elixir).

---

## Features

- **Zero External Dependencies:** Pure Elixir + OTP 27+ `:json` stdlib.
- **Line-Oriented Streaming Parser (`OpenUILang.stream_parser/2`):** Re-parses and materializes the UI tree incrementally on every incoming LLM token chunk so Terminal UIs ([`openui_tui`](https://github.com/boxxxie/openui_tui)) or Phoenix LiveViews can render progressive frames in real time.
- **Positional-to-Named Schema Binding (`OpenUILang.compile_schema/1`):** Binds compact positional calls (`Stat("Throughput", $live_ops, "+12%", Sparkline($history, "info"))`) to JSON Schema `properties` in exact document key insertion order (`OpenUILang.decode_json!/1`).
- **Statement-Level Diff & Patch Merging (`OpenUILang.merge_statements/3`):** Allows LLMs to emit surgical 1–3 line statement patches (`kpis = Row([...])`) instead of regenerating an entire UI program, automatically pruning orphaned subtrees.
- **Reactive Runtime Evaluator (`OpenUILang.evaluate_result/2`):**
  - Reactive `$state` bindings (`$slab = "1"`, `@Set($slab, "2")`, `@Reset($slab)`).
  - Collection & string built-ins (`@Each`, `@Filter`, `@Sort`, `@Count`, `@Sum`, `@Avg`, `@Min`, `@Max`, `@Round`, `@Concat`, `@Join`, `@If`, `@Default`).
  - Action plans (`@ToAssistant`, `@OpenUrl`, `@Run`, `@Set`, `@Reset`, `@Sequence`).
- **Stream Demultiplexer & Flat Symbol Extractor (`OpenUILang.demux/1`, `OpenUILang.parse_symbols/1`):** Separates conversational Markdown prose from fenced/unfenced `openui-lang` code and extracts a flat symbol table with `{:ref, id}` and `{:var, "$name"}` nodes for fixed-width TUI layout engines.
- **Round-Trip Serializer & Prompt Generator:**
  - `OpenUILang.json_to_openui/3` converts evaluated element trees back into canonical `openui-lang` source code.
  - `OpenUILang.generate_system_prompt/1` generates compact LLM system prompts directly from your component library JSON schema.

---

## Installation

Add `openui_lang` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:openui_lang, github: "boxxxie/openui_lang"}
    # Or when developing locally alongside openui_tui:
    # {:openui_lang, path: "../openui_lang"}
  ]
end
```

---

## Quick Start

### 1. Compile a Component Library Schema

Positional arguments in `openui-lang` map to JSON Schema `properties` in document key order. Use `OpenUILang.decode_json!/1` to preserve property insertion order before calling `OpenUILang.compile_schema/1`:

```elixir
schema =
  File.read!("library.json")
  |> OpenUILang.decode_json!()
  |> OpenUILang.compile_schema()
```

### 2. Parse & Evaluate an `openui-lang` Program

```elixir
code = """
$selected_env = "prod"
root = Dashboard("Cluster Health", "hel1-dc2", [banner, kpis, controls])
banner = Alert("success", "All nodes healthy")
kpis = Row([
  Stat("Requests/s", "14.2k", "+8%", Sparkline([11, 12, 13, 14], "info")),
  Stat("Error Rate", "0.01%", "-0.02%", Sparkline([2, 1, 1, 0], "ok"))
])
controls = Form([
  Select("Environment", $selected_env, ["prod", "staging", "dev"])
], [
  Button("Inspect Environment", @ToAssistant("Show node breakdown for " + $selected_env))
])
"""

parse_result = OpenUILang.parse(code, schema)

evaluated =
  OpenUILang.evaluate_result(parse_result, %{
    cat: schema,
    functions: %{
      "Upper" => fn %{"text" => text} -> String.upcase(to_string(text || "")) end
    }
  })

evaluated["root"]         # Evaluated element tree (%{"type" => "Dashboard", "props" => ...})
evaluated["state"]        # %{"$selected_env" => "prod"}
evaluated["errors"]       # []
evaluated["errorObjects"] # Structured diagnostics with source, code, component, path, and hint
```

### 3. Progressive Streaming from LLM Token Chunks

```elixir
sp = OpenUILang.stream_parser(schema)

{partial_parse, sp} = OpenUILang.push_chunk(sp, "root = Stack([Card(\"Hello\", ", false)
{final_parse, _sp}  = OpenUILang.push_chunk(sp, "[Text(\"World\")])])\n", true)

evaluated = OpenUILang.evaluate_result(final_parse, %{cat: schema})
```

### 4. Incremental Statement Patching (`merge_statements/3`)

When evolving a UI in chat, merge new or updated statements into the existing program while automatically pruning orphaned subtrees:

```elixir
base_code = """
root = Panel("Overview", [kpis], "info")
kpis = Row([Stat("CPU", "42%")])
"""

patch_code = """
kpis = Row([Stat("CPU", "38%"), Stat("RAM", "6.4 GB")])
"""

merged = OpenUILang.merge_statements(base_code, patch_code)
```

### 5. Demultiplexing Mixed Chat Prose & OpenUI Code

````elixir
mixed_llm_output = """
I added a real-time memory stat card to the KPI row:

```openui
kpis = Row([Stat("CPU", "38%"), Stat("RAM", "6.4 GB")])
```
"""

%{prose: prose, code: openui_code} = OpenUILang.demux(mixed_llm_output)
symbols = OpenUILang.parse_symbols(openui_code)
# symbols["kpis"] => {"Row", [[{"Stat", ["CPU", "38%"]}, {"Stat", ["RAM", "6.4 GB"]}]]}
````

---

## Architecture Overview

| Module | File | Responsibility |
| :--- | :--- | :--- |
| `OpenUILang` | [`lib/openui_lang.ex`](lib/openui_lang.ex) | Public facade for parsing, streaming, evaluating, merging, demuxing, and prompt generation |
| `OpenUILang.AST` | [`lib/openui_lang/ast.ex`](lib/openui_lang/ast.ex) | AST node constructors and helpers |
| `OpenUILang.Lexer` | [`lib/openui_lang/lexer.ex`](lib/openui_lang/lexer.ex) | Statement splitter, string/comment scanner, and tokenizer |
| `OpenUILang.Statements` | [`lib/openui_lang/statements.ex`](lib/openui_lang/statements.ex) | Top-level assignment, query, mutation, and `$state` declaration classifier |
| `OpenUILang.Expressions` | [`lib/openui_lang/expressions.ex`](lib/openui_lang/expressions.ex) | Pratt expression parser for literals, operators, lambdas, components, and `@` builtins/actions |
| `OpenUILang.Parser` | [`lib/openui_lang/parser.ex`](lib/openui_lang/parser.ex) | Batch & streaming parser orchestrator and flat symbol table extractor (`parse_symbols/1`) |
| `OpenUILang.Materialize` | [`lib/openui_lang/materialize.ex`](lib/openui_lang/materialize.ex) | Reference resolution, cycle detection, orphan tracking, and schema validation |
| `OpenUILang.Schema` | [`lib/openui_lang/schema.ex`](lib/openui_lang/schema.ex) | Order-preserving JSON decoder (`decode_json!/1`), schema compiler, and positional-to-named prop mapper |
| `OpenUILang.Evaluator` | [`lib/openui_lang/evaluator.ex`](lib/openui_lang/evaluator.ex) | Runtime evaluator for `$state` bindings, expressions, and `@Action` plans |
| `OpenUILang.Builtins` | [`lib/openui_lang/builtins.ex`](lib/openui_lang/builtins.ex) | Standard library built-in functions (`@Each`, `@Filter`, `@Sort`, `@Sum`, `@Avg`, `@If`, etc.) |
| `OpenUILang.Rules` | [`lib/openui_lang/rules.ex`](lib/openui_lang/rules.ex) | Form and property validation rule engine (`validate_rules/2`) |
| `OpenUILang.Merge` | [`lib/openui_lang/merge.ex`](lib/openui_lang/merge.ex) | Statement-level diff merger (`merge_statements/3`) with unreachable-statement garbage collection |
| `OpenUILang.Message` | [`lib/openui_lang/message.ex`](lib/openui_lang/message.ex) | OpenUI message envelope builder (`build_message/1`), parser (`parse_message/1`), and prose/code demuxer (`demux/1`) |
| `OpenUILang.Prompt` | [`lib/openui_lang/prompt.ex`](lib/openui_lang/prompt.ex) | Generates OpenUI 1.0 LLM system prompts from component catalog JSON specs |
| `OpenUILang.Serialize` | [`lib/openui_lang/serialize.ex`](lib/openui_lang/serialize.ex) | Round-trip serializer (`json_to_openui/3`) from evaluated element trees back to `openui-lang` |
| `OpenUILang.Error` | [`lib/openui_lang/error.ex`](lib/openui_lang/error.ex) | Structured diagnostic and error-hint builder |

---

## Running Tests

Run the standalone test suite:

```bash
mix test
```

## Companion Project

- **[`openui_tui`](https://github.com/boxxxie/openui_tui):** Conversational Terminal UI (TUI) Studio, Jido Agentic UI Builder, and 1Hz Live Telemetry Engine built on `openui_lang`.

---

## License

MIT
