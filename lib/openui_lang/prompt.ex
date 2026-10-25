defmodule OpenUILang.Prompt do
  @moduledoc false

  alias OpenUILang.Schema

  @default_preamble """
  You are an assistant that generates interactive user interfaces using OpenUI Lang, a compact, line-oriented declarative UI language.
  Output ONLY valid OpenUI Lang statements, one statement per line, starting with `root = ...`.
  """

  @spec generate_system_prompt(map(), keyword()) :: String.t()
  def generate_system_prompt(library_spec, opts \\ []) when is_map(library_spec) do
    preamble = Keyword.get(opts, :preamble, @default_preamble)
    root = Map.get(library_spec, "root") || Map.get(library_spec, :root) || "Root"
    components = Map.get(library_spec, "components") || Map.get(library_spec, :components) || %{}
    functions = Map.get(library_spec, "functions") || Map.get(library_spec, :functions) || %{}
    actions = Map.get(library_spec, "actions") || Map.get(library_spec, :actions) || %{}
    examples = Keyword.get(opts, :examples, [])
    additional_rules = Keyword.get(opts, :additional_rules, [])

    comp_lines =
      Schema.ordered_keys(components)
      |> Enum.map(fn name ->
        spec = Map.get(components, name)
        sig = Map.get(spec, "signature") || Map.get(spec, :signature) || "#{name}()"
        desc = Map.get(spec, "description") || Map.get(spec, :description)
        if desc && desc != "", do: "- `#{sig}` — #{desc}", else: "- `#{sig}`"
      end)

    fn_lines =
      Schema.ordered_keys(functions)
      |> Enum.map(fn name ->
        spec = Map.get(functions, name)
        sig = Map.get(spec, "signature") || Map.get(spec, :signature) || name
        desc = Map.get(spec, "description") || Map.get(spec, :description)
        if desc && desc != "", do: "- `@#{sig}` — #{desc}", else: "- `@#{sig}`"
      end)

    act_lines =
      Schema.ordered_keys(actions)
      |> Enum.map(fn name ->
        spec = Map.get(actions, name)
        sig = Map.get(spec, "signature") || Map.get(spec, :signature) || name
        desc = Map.get(spec, "description") || Map.get(spec, :description)
        if desc && desc != "", do: "- `@#{sig}` — #{desc}", else: "- `@#{sig}`"
      end)

    sections = [
      String.trim(preamble),
      """
      ## Syntax Rules
      1. Every line is `identifier = Expression`.
      2. The entry point MUST be `root = #{root}(...)`.
      3. Positional arguments map to component properties in the order listed in their signature.
      4. Use `null` to skip optional positional arguments.
      5. Define top-level layout first (`root = ...`), then define referenced child identifiers on subsequent lines.
      """
      |> String.trim(),
      "## Components\n" <> Enum.join(comp_lines, "\n")
    ]

    sections =
      if fn_lines != [] do
        sections ++ ["## Custom Functions\n" <> Enum.join(fn_lines, "\n")]
      else
        sections
      end

    sections =
      if act_lines != [] do
        sections ++ ["## Custom Actions\n" <> Enum.join(act_lines, "\n")]
      else
        sections
      end

    sections =
      if additional_rules != [] do
        rules_text = Enum.map_join(additional_rules, "\n", &"- #{&1}")
        sections ++ ["## Additional Rules\n" <> rules_text]
      else
        sections
      end

    sections =
      if examples != [] do
        ex_text = Enum.join(examples, "\n\n")
        sections ++ ["## Examples\n" <> ex_text]
      else
        sections
      end

    Enum.join(sections, "\n\n")
  end
end
