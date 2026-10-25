defmodule OpenUILang.Schema do
  @moduledoc false

  alias OpenUILang.AST

  @action_def_names ["ActionExpression", "OpenUrl", "ToAssistant"]

  @doc """
  Decodes JSON while preserving object key order in `"__keys__"`.
  """
  @spec decode_json!(String.t()) :: term()
  def decode_json!(json_bin) when is_binary(json_bin) do
    decoders = %{
      null: nil,
      object_start: fn _ -> [] end,
      object_push: fn k, v, acc -> [{k, v} | acc] end,
      object_finish: fn acc, old_acc ->
        ordered = Enum.reverse(acc)
        keys = Enum.map(ordered, &elem(&1, 0))
        map = Map.new(ordered) |> Map.put("__keys__", keys)
        {map, old_acc}
      end
    }

    {res, _, _} = :json.decode(json_bin, :ok, decoders)
    res
  end

  @doc """
  Strips `"__keys__"` recursively from a decoded JSON value.
  """
  @spec strip_keys_meta(term()) :: term()
  def strip_keys_meta(v) when is_list(v), do: Enum.map(v, &strip_keys_meta/1)

  def strip_keys_meta(v) when is_map(v) do
    v
    |> Map.delete("__keys__")
    |> Map.new(fn {k, val} -> {k, strip_keys_meta(val)} end)
  end

  def strip_keys_meta(v), do: v

  @spec ordered_keys(map() | nil) :: [String.t()]
  def ordered_keys(nil), do: []

  def ordered_keys(%{"__keys__" => keys} = map) when is_list(keys) do
    Enum.filter(keys, &Map.has_key?(map, &1))
  end

  def ordered_keys(map) when is_map(map) do
    Map.keys(map) |> Enum.reject(&(&1 == "__keys__"))
  end

  @spec compile_schema(map() | nil) :: map()
  def compile_schema(nil) do
    %{
      components: %{},
      call_defs: OpenUILang.Builtins.builtin_calls(),
      bindable: %{},
      functions_schema: %{},
      actions_schema: %{},
      root: nil
    }
  end

  def compile_schema(%{"schema" => inner_schema} = lib_spec) when is_map(inner_schema) do
    compiled = compile_schema(inner_schema)
    bindable = extract_bindable_from_components(Map.get(lib_spec, "components", %{}))

    %{
      compiled
      | bindable: Map.merge(compiled.bindable, bindable),
        root: Map.get(lib_spec, "root") || compiled.root
    }
  end

  def compile_schema(schema) when is_map(schema) do
    props_map = Map.get(schema, "properties")
    comp_set = if is_map(props_map), do: MapSet.new(ordered_keys(props_map)), else: nil
    defs_map = Map.get(schema, "$defs", %{})
    actions_map = Map.get(schema, "actions", %{})
    functions_map = Map.get(schema, "functions", %{})

    action_names = @action_def_names ++ ordered_keys(actions_map)

    action_defs =
      Enum.reduce(action_names, %{}, fn name, acc ->
        body = Map.get(defs_map, name)

        if is_map(body) and (comp_set == nil or not MapSet.member?(comp_set, name)) do
          Map.put(acc, "#/$defs/#{name}", body)
        else
          acc
        end
      end)

    components =
      Enum.reduce(ordered_keys(defs_map), %{}, fn name, acc ->
        skip? =
          if comp_set != nil do
            not MapSet.member?(comp_set, name)
          else
            Map.has_key?(action_defs, "#/$defs/#{name}")
          end

        if skip? do
          acc
        else
          def_obj = Map.get(defs_map, name, %{})
          Map.put(acc, name, %{params: compile_params(def_obj, action_defs)})
        end
      end)

    call_defs =
      OpenUILang.Builtins.builtin_calls()
      |> then(fn cd ->
        Enum.reduce(ordered_keys(functions_map), cd, fn name, acc ->
          fn_def = Map.get(functions_map, name, %{})
          params_def = Map.get(fn_def, "params", %{})
          Map.put(acc, name, %{kind: :function, params: compile_params(params_def, action_defs)})
        end)
      end)
      |> then(fn cd ->
        Enum.reduce(ordered_keys(actions_map), cd, fn name, acc ->
          act_def = Map.get(actions_map, name, %{})
          params_def = Map.get(act_def, "params", %{})
          Map.put(acc, name, %{kind: :action, params: compile_params(params_def, action_defs)})
        end)
      end)

    %{
      components: components,
      call_defs: call_defs,
      bindable: Map.get(schema, "bindable", %{}),
      functions_schema: functions_map,
      actions_schema: actions_map,
      root: Map.get(schema, "root")
    }
  end

  defp extract_bindable_from_components(comps) when is_map(comps) do
    Enum.reduce(comps, %{}, fn
      {"__keys__", _}, acc ->
        acc

      {comp_name, %{"signature" => sig}}, acc when is_binary(sig) ->
        props =
          Regex.scan(~r/(\w+)\??:\s*\$binding</, sig)
          |> Enum.map(fn [_, prop_name] -> prop_name end)
          |> MapSet.new()

        if MapSet.size(props) > 0, do: Map.put(acc, comp_name, props), else: acc

      _, acc ->
        acc
    end)
  end

  defp extract_bindable_from_components(_), do: %{}

  defp compile_params(def_obj, action_defs) when is_map(def_obj) do
    properties = Map.get(def_obj, "properties", %{})
    required = Map.get(def_obj, "required", [])

    Enum.map(ordered_keys(properties), fn key ->
      prop_schema = Map.get(properties, key)

      inlined_schema =
        if map_size(action_defs) > 0 do
          inline_action_refs(prop_schema, action_defs)
        else
          prop_schema
        end

      %{
        name: key,
        required: key in required,
        default_value: get_schema_default_value(prop_schema),
        schema: inlined_schema
      }
    end)
  end

  defp compile_params(_, _), do: []

  defp inline_action_refs(%{"$ref" => ref} = node, defs) when is_binary(ref) do
    case Map.get(defs, ref) do
      nil -> node
      target -> inline_action_refs(target, defs)
    end
  end

  defp inline_action_refs(node, defs) when is_list(node) do
    Enum.map(node, &inline_action_refs(&1, defs))
  end

  defp inline_action_refs(node, defs) when is_map(node) do
    Map.new(node, fn {k, v} -> {k, inline_action_refs(v, defs)} end)
  end

  defp inline_action_refs(node, _defs), do: node

  @spec get_schema_default_value(term()) :: {:ok, term()} | :undefined
  def get_schema_default_value(prop) when is_map(prop) do
    if Map.has_key?(prop, "default") do
      {:ok, strip_keys_meta(Map.get(prop, "default"))}
    else
      :undefined
    end
  end

  def get_schema_default_value(_), do: :undefined

  @spec resolve_invalid_value(boolean(), {:ok, term()} | :undefined) ::
          {:ok, term()} | :omit | :invalid
  def resolve_invalid_value(_required, {:ok, default_val}), do: {:ok, default_val}
  def resolve_invalid_value(true, :undefined), do: :invalid
  def resolve_invalid_value(false, :undefined), do: :omit

  @spec build_params_signature(String.t(), [map()]) :: String.t()
  def build_params_signature(component, params) do
    rendered =
      Enum.map(params, fn p ->
        type = get_type_from_schema(p.schema)
        marked = if p.required, do: "#{p.name}*", else: p.name
        if type, do: "#{marked}: #{type}", else: marked
      end)
      |> Enum.join(", ")

    "#{component}(#{rendered})"
  end

  defp get_type_from_schema(prop) when is_map(prop) do
    cond do
      is_binary(Map.get(prop, "$ref")) ->
        prop["$ref"] |> String.split("/") |> List.last()

      is_list(Map.get(prop, "enum")) ->
        prop["enum"]
        |> Enum.map(&:json.encode/1)
        |> Enum.map(&IO.iodata_to_binary/1)
        |> Enum.join("|")

      Map.has_key?(prop, "const") ->
        :json.encode(prop["const"]) |> IO.iodata_to_binary()

      prop["type"] in ["number", "integer"] ->
        "number"

      is_binary(prop["type"]) ->
        prop["type"]

      true ->
        nil
    end
  end

  defp get_type_from_schema(_), do: nil

  # ── Validation Issues ────────────────────────────────────────────────────

  @spec push_validation_issue(map(), String.t(), String.t(), map()) :: map()
  def push_validation_issue(ctx, component, path, issue) do
    err = %{
      code: issue.code,
      component: component,
      path: path,
      message: validation_message(component, path, issue),
      statement_id: ctx.current_statement_id
    }

    err =
      if issue.code == "no-root" and Map.get(issue, :reason) == "fallback" do
        Map.put(err, :severity, "warning")
      else
        err
      end

    %{ctx | errors: ctx.errors ++ [err]}
  end

  defp validation_message(_component, path, %{code: "type-mismatch"} = issue) do
    ~s(field "#{path}" expects #{issue.expected} but got #{issue.actual})
  end

  defp validation_message(_component, path, %{code: "missing-required"} = issue) do
    sig = if issue[:signature], do: " — signature: #{issue.signature}", else: ""
    ~s(missing required field "#{path}"#{sig})
  end

  defp validation_message(_component, path, %{code: "null-required"} = issue) do
    sig = if issue[:signature], do: " — signature: #{issue.signature}", else: ""
    ~s(required field "#{path}" cannot be null#{sig})
  end

  defp validation_message(component, _path, %{code: "unknown-component"} = issue) do
    avail =
      if is_list(issue[:available]) and issue.available != [] do
        ". Available components: #{Enum.join(issue.available, ", ")}"
      else
        ""
      end

    ~s(Unknown component "#{component}" — not found in catalog or builtins#{avail})
  end

  defp validation_message(component, _path, %{code: "inline-reserved"}) do
    "#{component}() must be declared as a top-level statement, not used inline as a value"
  end

  defp validation_message(component, _path, %{code: "excess-args"} = issue) do
    "#{component} takes #{issue.declared} arg(s), got #{issue.got} (#{issue.got - issue.declared} excess dropped)"
  end

  defp validation_message(component, _path, %{code: "unknown-function"}) do
    ~s(Unknown function "@#{component}": not a built-in or action step. The call evaluates to null)
  end

  defp validation_message(component, _path, %{code: "no-root"} = issue) do
    case issue[:reason] do
      "not-component" ->
        "root does not evaluate to a component"

      "fallback" ->
        "No root statement. Rendering the first statement that calls the root component #{component}"

      _ ->
        if component != "" do
          "No root statement, and no statement calls the root component #{component}"
        else
          "No root statement"
        end
    end
  end

  # ── Schema Value Validation ──────────────────────────────────────────────

  @spec validate_schema_value(term(), term(), String.t(), String.t(), map()) ::
          {{:ok, term()} | :invalid, map()}
  def validate_schema_value(value, schema, _component, _path, ctx)
      when not is_map(schema) or is_nil(value) do
    {{:ok, value}, ctx}
  end

  def validate_schema_value(value, schema, component, path, ctx) do
    cond do
      AST.is_ast_node?(value) ->
        {{:ok, value}, ctx}

      AST.is_element_node?(value) ->
        validate_element_position(value, schema, component, path, ctx)

      composite_schema?(schema) ->
        if only_component_slot?(schema, ctx) do
          expected = slot_ref_names(schema) |> Enum.reject(&is_nil/1) |> Enum.join(" | ")

          actual =
            cond do
              is_list(value) -> "array"
              is_map(value) -> "plain object"
              true -> js_typeof(value)
            end

          ctx =
            push_validation_issue(ctx, component, path, %{
              code: "type-mismatch",
              expected: expected,
              actual: actual
            })

          {:invalid, ctx}
        else
          {{:ok, value}, ctx}
        end

      schema["type"] == "object" ->
        validate_object_value(value, schema, component, path, ctx)

      schema["type"] == "array" ->
        validate_array_value(value, schema, component, path, ctx)

      true ->
        validate_leaf_value(value, schema, component, path, ctx)
    end
  end

  defp validate_element_position(element, schema, component, path, ctx) do
    if composite_schema?(schema) do
      {{:ok, element}, ctx}
    else
      if is_binary(schema["type"]) or is_list(schema["enum"]) or Map.has_key?(schema, "const") do
        expected = if is_binary(schema["type"]), do: schema["type"], else: "a literal value"

        ctx =
          push_validation_issue(ctx, component, path, %{
            code: "type-mismatch",
            expected: expected,
            actual: ~s(component "#{element.type_name}")
          })

        {:invalid, ctx}
      else
        {{:ok, element}, ctx}
      end
    end
  end

  defp validate_object_value(value, schema, component, path, ctx) do
    if not is_map(value) or is_list(value) do
      ctx =
        push_validation_issue(ctx, component, path, %{
          code: "type-mismatch",
          expected: "object",
          actual: js_type(value)
        })

      {:invalid, ctx}
    else
      props = if is_map(schema["properties"]), do: schema["properties"], else: %{}
      required = if is_list(schema["required"]), do: schema["required"], else: []

      {out, invalid, ctx} =
        if not ctx.partial do
          Enum.reduce(required, {value, false, ctx}, fn key, {acc_obj, inv, acc_ctx} ->
            present? = Map.has_key?(acc_obj, key)
            val = Map.get(acc_obj, key)

            if not present? or is_nil(val) do
              case get_schema_default_value(Map.get(props, key)) do
                {:ok, fallback} ->
                  {Map.put(acc_obj, key, fallback), inv, acc_ctx}

                :undefined ->
                  code = if present?, do: "null-required", else: "missing-required"

                  acc_ctx =
                    push_validation_issue(acc_ctx, component, "#{path}/#{key}", %{code: code})

                  {acc_obj, true, acc_ctx}
              end
            else
              {acc_obj, inv, acc_ctx}
            end
          end)
        else
          {value, false, ctx}
        end

      {out, invalid, ctx} =
        Enum.reduce(ordered_keys(props), {out, invalid, ctx}, fn key, {acc_obj, inv, acc_ctx} ->
          if not Map.has_key?(acc_obj, key) do
            {acc_obj, inv, acc_ctx}
          else
            sub = Map.get(props, key)
            cur_val = Map.get(acc_obj, key)

            {res, acc_ctx} =
              validate_schema_value(cur_val, sub, component, "#{path}/#{key}", acc_ctx)

            case res do
              {:ok, next_val} ->
                {Map.put(acc_obj, key, next_val), inv, acc_ctx}

              :invalid ->
                case resolve_invalid_value(key in required, get_schema_default_value(sub)) do
                  {:ok, default_val} -> {Map.put(acc_obj, key, default_val), inv, acc_ctx}
                  :omit -> {Map.delete(acc_obj, key), inv, acc_ctx}
                  :invalid -> {acc_obj, true, acc_ctx}
                end
            end
          end
        end)

      if invalid, do: {:invalid, ctx}, else: {{:ok, out}, ctx}
    end
  end

  defp validate_array_value(value, schema, component, path, ctx) do
    if not is_list(value) do
      ctx =
        push_validation_issue(ctx, component, path, %{
          code: "type-mismatch",
          expected: "array",
          actual: js_type(value)
        })

      {:invalid, ctx}
    else
      items_schema = schema["items"]

      if not is_map(items_schema) do
        {{:ok, value}, ctx}
      else
        {rev_items, ctx} =
          value
          |> Enum.with_index()
          |> Enum.reduce({[], ctx}, fn {item, idx}, {acc_items, acc_ctx} ->
            {res, acc_ctx} =
              validate_schema_value(item, items_schema, component, "#{path}/#{idx}", acc_ctx)

            case res do
              {:ok, next_item} -> {[next_item | acc_items], acc_ctx}
              :invalid -> {acc_items, acc_ctx}
            end
          end)

        {{:ok, Enum.reverse(rev_items)}, ctx}
      end
    end
  end

  defp validate_leaf_value(value, schema, component, path, ctx) do
    leaf = get_scalar_type_info(schema)

    cond do
      leaf == %{} ->
        {{:ok, value}, ctx}

      Map.has_key?(leaf, :enum_values) and ctx.partial ->
        {{:ok, value}, ctx}

      true ->
        case check_type_mismatch(value, leaf) do
          nil ->
            {{:ok, value}, ctx}

          %{expected: exp, actual: act} ->
            ctx =
              push_validation_issue(ctx, component, path, %{
                code: "type-mismatch",
                expected: exp,
                actual: act
              })

            {:invalid, ctx}
        end
    end
  end

  defp get_scalar_type_info(s) do
    cond do
      is_list(s["enum"]) -> %{enum_values: s["enum"]}
      Map.has_key?(s, "const") -> %{enum_values: [s["const"]]}
      s["type"] == "string" -> %{expected_type: "string"}
      s["type"] in ["number", "integer"] -> %{expected_type: "number"}
      s["type"] == "boolean" -> %{expected_type: "boolean"}
      true -> %{}
    end
  end

  defp check_type_mismatch(value, %{enum_values: enum_vals}) do
    actual_type = js_typeof(value)

    if actual_type not in ["string", "number", "boolean"] do
      nil
    else
      if value in enum_vals do
        nil
      else
        rendered_enum =
          enum_vals
          |> Enum.map(&(:json.encode(&1) |> IO.iodata_to_binary()))
          |> Enum.join(", ")

        %{
          expected: "one of [#{rendered_enum}]",
          actual: :json.encode(value) |> IO.iodata_to_binary()
        }
      end
    end
  end

  defp check_type_mismatch(value, %{expected_type: exp}) do
    if js_typeof(value) != exp do
      %{expected: exp, actual: js_type(value)}
    else
      nil
    end
  end

  defp composite_schema?(s) when is_map(s) do
    Map.has_key?(s, "$ref") or Map.has_key?(s, "anyOf") or Map.has_key?(s, "oneOf") or
      Map.has_key?(s, "allOf")
  end

  defp slot_ref_names(s) do
    options = s["anyOf"] || s["oneOf"] || [s]

    Enum.map(options, fn
      %{"$ref" => ref} when is_binary(ref) -> ref |> String.split("/") |> List.last()
      _ -> nil
    end)
  end

  defp only_component_slot?(s, ctx) do
    names = slot_ref_names(s)
    comps = if ctx.cat, do: ctx.cat.components, else: %{}
    names != [] and Enum.all?(names, fn n -> n != nil and Map.has_key?(comps, n) end)
  end

  defp js_typeof(v) when is_binary(v), do: "string"
  defp js_typeof(v) when is_number(v), do: "number"
  defp js_typeof(v) when is_boolean(v), do: "boolean"
  defp js_typeof(_), do: "object"

  defp js_type(v) when is_list(v), do: "array"
  defp js_type(v), do: js_typeof(v)
end
