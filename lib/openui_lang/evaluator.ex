defmodule OpenUILang.Evaluator do
  @moduledoc false

  alias OpenUILang.{AST, Builtins, Lexer, Materialize, Schema}

  @spec is_reactive_assign?(term()) :: boolean()
  def is_reactive_assign?(%{__reactive: "assign"}), do: true
  def is_reactive_assign?(_), do: false

  @spec is_action_plan?(term()) :: boolean()
  def is_action_plan?(%{steps: steps}) when is_list(steps), do: true
  def is_action_plan?(_), do: false

  @spec own_steps(map()) :: map()
  def own_steps(%{steps: steps} = plan) do
    filtered =
      Enum.filter(steps, fn s ->
        Map.get(s, :type) != "custom_action" or Map.get(s, :__own_custom_step__) == true
      end)

    %{plan | steps: filtered}
  end

  @spec evaluate(map(), map(), map() | nil) :: term()
  def evaluate(node, context, schema_ctx \\ nil)

  def evaluate(%{k: :str, v: v}, _context, _schema_ctx), do: v
  def evaluate(%{k: :num, v: v}, _context, _schema_ctx), do: v
  def evaluate(%{k: :bool, v: v}, _context, _schema_ctx), do: v
  def evaluate(%{k: :null}, _context, _schema_ctx), do: nil
  def evaluate(%{k: :ph}, _context, _schema_ctx), do: nil

  def evaluate(%{k: :state_ref, n: n}, context, _schema_ctx) do
    extra = Map.get(context, :extra_scope, %{})

    if Map.has_key?(extra, n) do
      Map.get(extra, n)
    else
      context.get_state.(n)
    end
  end

  def evaluate(%{k: k, n: n}, context, _schema_ctx) when k in [:ref, :runtime_ref] do
    context.resolve_ref.(n)
  end

  def evaluate(%{k: :arr, els: els}, context, _schema_ctx) do
    Enum.map(els, &evaluate(&1, context))
  end

  def evaluate(%{k: :obj, entries: entries}, context, _schema_ctx) do
    pairs = Enum.map(entries, fn {k, v} -> {k, evaluate(v, context)} end)
    keys = Enum.map(pairs, &elem(&1, 0)) |> Enum.uniq()
    Map.new(pairs) |> Map.put("__keys__", keys)
  end

  def evaluate(%{k: :comp, name: name} = node, context, schema_ctx) do
    fns = Map.get(context, :functions, %{})
    acts = Map.get(context, :actions, %{})

    cond do
      Builtins.is_builtin_function?(name) ->
        def_info = Map.fetch!(Builtins.builtin_functions(), name)

        if Map.get(def_info, :lazy) == true do
          evaluate_lazy_builtin(name, node.args, context, schema_ctx)
        else
          Builtins.call_builtin(name, evaluate_args(node, context, def_info.params))
        end

      Builtins.is_step?(name) ->
        evaluate_action_call(node, context)

      is_map(fns) and Map.has_key?(fns, name) ->
        call_function(name, Map.fetch!(fns, name), node, context)

      is_map(acts) and Map.has_key?(acts, name) ->
        def_act = Map.fetch!(acts, name)
        params_schema = Map.get(def_act, "params") || Map.get(def_act, :params) || %{}
        args = call_args(node, context, params_schema)

        if misses_required?(args, params_schema) do
          %{steps: []}
        else
          case check_value(args, params_schema, name, "", context, true) do
            :invalid ->
              %{steps: []}

            {:ok, checked_params} ->
              step = %{
                type: "custom_action",
                name: name,
                params: checked_params,
                __own_custom_step__: true
              }

              %{steps: [step]}
          end
        end

      is_map(Map.get(node, :mapped_props)) ->
        mapped_props = node.mapped_props

        props =
          Map.new(mapped_props, fn {key, val} ->
            reactive? = bindable_prop?(schema_ctx, name, key)

            resolved =
              cond do
                val.k == :state_ref and reactive? ->
                  %{
                    __reactive: "assign",
                    target: val.n,
                    expr: %{k: :state_ref, n: "$value"}
                  }

                val.k == :state_ref ->
                  if schema_ctx != nil, do: context.get_state.(val.n), else: val

                true ->
                  evaluate(val, context, schema_ctx)
              end

            {key, resolved}
          end)

        props =
          if schema_ctx != nil do
            Map.new(props, fn {key, val} ->
              cond do
                AST.is_element_node?(val) ->
                  {key, evaluate_element_inline(val, context, schema_ctx)}

                is_list(val) ->
                  {key,
                   Enum.map(val, fn item ->
                     if AST.is_element_node?(item) do
                       evaluate_element_inline(item, context, schema_ctx)
                     else
                       item
                     end
                   end)}

                true ->
                  {key, val}
              end
            end)
          else
            props
          end

        %{
          type: "element",
          type_name: name,
          props: props,
          partial: false,
          has_dynamic_props: true
        }

      true ->
        nil
    end
  end

  def evaluate(%{k: :bin_op, op: "&&", left: l, right: r}, context, _schema_ctx) do
    left = evaluate(l, context)
    if Builtins.truthy?(left), do: evaluate(r, context), else: left
  end

  def evaluate(%{k: :bin_op, op: "||", left: l, right: r}, context, _schema_ctx) do
    left = evaluate(l, context)
    if Builtins.truthy?(left), do: left, else: evaluate(r, context)
  end

  def evaluate(%{k: :bin_op, op: op, left: l, right: r}, context, _schema_ctx) do
    left = evaluate(l, context)
    right = evaluate(r, context)

    case op do
      "+" ->
        if is_binary(left) or is_binary(right) do
          Builtins.to_js_string(left) <> Builtins.to_js_string(right)
        else
          Lexer.normalize_number(Builtins.to_number(left) + Builtins.to_number(right))
        end

      "-" ->
        Lexer.normalize_number(Builtins.to_number(left) - Builtins.to_number(right))

      "*" ->
        Lexer.normalize_number(Builtins.to_number(left) * Builtins.to_number(right))

      "/" ->
        rn = Builtins.to_number(right)
        if rn == 0, do: 0, else: Lexer.normalize_number(Builtins.to_number(left) / rn)

      "%" ->
        rn = Builtins.to_number(right)

        if rn == 0 do
          0
        else
          ln = Builtins.to_number(left)

          if is_integer(ln) and is_integer(rn) do
            rem(ln, rn)
          else
            Lexer.normalize_number(:math.fmod(ln * 1.0, rn * 1.0))
          end
        end

      "==" ->
        Builtins.loose_equal?(left, right)

      "!=" ->
        not Builtins.loose_equal?(left, right)

      ">" ->
        Builtins.to_number(left) > Builtins.to_number(right)

      "<" ->
        Builtins.to_number(left) < Builtins.to_number(right)

      ">=" ->
        Builtins.to_number(left) >= Builtins.to_number(right)

      "<=" ->
        Builtins.to_number(left) <= Builtins.to_number(right)

      _ ->
        nil
    end
  end

  def evaluate(%{k: :unary_op, op: "!", operand: op}, context, _schema_ctx) do
    not Builtins.truthy?(evaluate(op, context))
  end

  def evaluate(%{k: :unary_op, op: "-", operand: op}, context, _schema_ctx) do
    Lexer.normalize_number(-Builtins.to_number(evaluate(op, context)))
  end

  def evaluate(%{k: :unary_op}, _context, _schema_ctx), do: nil

  def evaluate(%{k: :ternary, cond: c, then: t, else: e}, context, schema_ctx) do
    if Builtins.truthy?(evaluate(c, context)) do
      evaluate(t, context, schema_ctx)
    else
      evaluate(e, context, schema_ctx)
    end
  end

  def evaluate(%{k: :member, obj: obj_node, field: field}, context, _schema_ctx) do
    obj = evaluate(obj_node, context)

    cond do
      obj == nil ->
        nil

      is_list(obj) ->
        if field == "length" do
          length(obj)
        else
          int_idx =
            case Integer.parse(field) do
              {idx, ""} when idx >= 0 -> idx
              _ -> nil
            end

          Enum.map(obj, fn item ->
            cond do
              is_map(item) and not AST.is_element_node?(item) ->
                Map.get(item, field)

              is_list(item) and int_idx != nil ->
                Enum.at(item, int_idx)

              true ->
                nil
            end
          end)
        end

      is_map(obj) and not AST.is_element_node?(obj) ->
        Map.get(obj, field)

      true ->
        nil
    end
  end

  def evaluate(%{k: :index, obj: obj_node, index: idx_node}, context, _schema_ctx) do
    obj = evaluate(obj_node, context)
    idx = evaluate(idx_node, context)

    cond do
      obj == nil or idx == nil ->
        nil

      is_list(obj) ->
        i = Builtins.to_number(idx) |> trunc()
        if i >= 0, do: Enum.at(obj, i), else: nil

      is_map(obj) and not AST.is_element_node?(obj) ->
        Map.get(obj, Builtins.to_js_string(idx))

      true ->
        nil
    end
  end

  def evaluate(%{k: :assign, target: target, value: val}, _context, _schema_ctx) do
    %{
      __reactive: "assign",
      target: target,
      expr: val
    }
  end

  # ── Tree & Prop Evaluation ───────────────────────────────────────────────

  @spec evaluate_root(map(), map()) :: {map() | nil, [map()]}
  def evaluate_root(result, eval_ctx) do
    errors_ref = :ets.new(:runtime_errors, [:duplicate_bag, :private])

    try do
      cat = Map.get(eval_ctx, :cat)
      schema_ctx = %{cat: cat}
      eval_ctx = Map.put(eval_ctx, :errors_ets, errors_ref) |> Map.put(:schema_ctx, schema_ctx)

      tree =
        cond do
          Map.get(result, :root) != nil ->
            evaluate_element_props(result.root, eval_ctx)

          Map.get(result, :root_expression) != nil ->
            val = evaluate(result.root_expression, eval_ctx.ctx, schema_ctx)

            if AST.is_element_node?(val) do
              evaluate_element_props(val, eval_ctx)
            else
              record_runtime_error(errors_ref, %{
                source: "runtime",
                code: "no-root",
                statement_id: "root",
                message: "root does not evaluate to a component"
              })

              nil
            end

          true ->
            nil
        end

      runtime_errors =
        case :ets.lookup(errors_ref, :err) do
          [] -> []
          rows -> Enum.map(rows, fn {:err, err} -> err end)
        end

      {tree, runtime_errors}
    after
      :ets.delete(errors_ref)
    end
  end

  @spec evaluate_element_props(map(), map()) :: map()
  def evaluate_element_props(%{has_dynamic_props: false} = el, _eval_ctx), do: el

  def evaluate_element_props(el, eval_ctx) do
    schema_ctx = Map.get(eval_ctx, :schema_ctx) || %{cat: Map.get(eval_ctx, :cat)}
    type_name = el.type_name
    errors_ref = Map.get(eval_ctx, :errors_ets)
    has_custom? = Map.get(eval_ctx, :has_custom, true)

    evaluated_props =
      Map.new(el.props, fn {prop_key, value} ->
        if not is_map(value) and not is_list(value) do
          {prop_key, value}
        else
          reactive? = bindable_prop?(schema_ctx, type_name, prop_key)

          prop_ctx =
            if has_custom? and errors_ref != nil do
              stmt_id = Map.get(el, :statement_id)
              err_target = {errors_ref, type_name, stmt_id, prop_key}
              %{eval_ctx | ctx: Map.put(eval_ctx.ctx, :err_target, err_target)}
            else
              eval_ctx
            end

          val =
            try do
              evaluate_prop_value(value, prop_ctx, schema_ctx, reactive?)
            rescue
              e ->
                if errors_ref do
                  emit_prop_error(
                    errors_ref,
                    type_name,
                    Map.get(el, :statement_id),
                    prop_key,
                    Exception.message(e)
                  )
                end

                value
            end

          {prop_key, val}
        end
      end)

    %{el | props: evaluated_props}
  end

  defp emit_prop_error(errors_ref, type_name, stmt_id, prop_key, msg) do
    record_runtime_error(errors_ref, %{
      source: "runtime",
      code: "runtime-error",
      component: type_name,
      statement_id: stmt_id,
      message: ~s(Evaluating prop "#{prop_key}" on #{type_name} failed: #{msg}),
      hint: ~s(Check the expression used for prop "#{prop_key}")
    })
  end

  defp report_ctx_error(context, msg) do
    cond do
      is_function(Map.get(context, :report_error), 1) ->
        context.report_error.(msg)

      match?({_, _, _, _}, Map.get(context, :err_target)) ->
        {errors_ref, type_name, stmt_id, prop_key} = context.err_target
        emit_prop_error(errors_ref, type_name, stmt_id, prop_key, msg)

      true ->
        :ok
    end
  end

  defp evaluate_element_inline(%{has_dynamic_props: false} = el, _context, _schema_ctx), do: el

  defp evaluate_element_inline(el, context, schema_ctx) do
    type_name = el.type_name

    evaluated_props =
      Map.new(el.props, fn {prop_key, value} ->
        if not is_map(value) and not is_list(value) do
          {prop_key, value}
        else
          reactive? = bindable_prop?(schema_ctx, type_name, prop_key)
          {prop_key, evaluate_prop_inline(value, context, schema_ctx, reactive?)}
        end
      end)

    %{el | props: evaluated_props}
  end

  defp evaluate_prop_inline(value, context, schema_ctx, reactive?) do
    res = evaluate_prop_core_inline(value, context, schema_ctx, reactive?)
    if is_action_plan?(res), do: own_steps(res), else: res
  end

  defp evaluate_prop_value(value, eval_ctx, schema_ctx, reactive?) do
    res = evaluate_prop_core_root(value, eval_ctx, schema_ctx, reactive?)
    if is_action_plan?(res), do: own_steps(res), else: res
  end

  defp evaluate_prop_core_root(nil, _eval_ctx, _schema_ctx, _reactive?), do: nil

  defp evaluate_prop_core_root(value, _eval_ctx, _schema_ctx, _reactive?)
       when not is_map(value) and not is_list(value) do
    value
  end

  defp evaluate_prop_core_root(value, eval_ctx, schema_ctx, reactive?) when is_list(value) do
    Enum.map(value, fn v -> evaluate_prop_value(v, eval_ctx, schema_ctx, reactive?) end)
  end

  defp evaluate_prop_core_root(value, eval_ctx, schema_ctx, reactive?) when is_map(value) do
    cond do
      AST.is_ast_node?(value) ->
        if value.k == :state_ref and reactive? do
          %{
            __reactive: "assign",
            target: value.n,
            expr: %{k: :state_ref, n: "$value"}
          }
        else
          context = eval_ctx.ctx
          result = evaluate(value, context, schema_ctx)

          cond do
            AST.is_element_node?(result) ->
              evaluate_element_props(result, eval_ctx)

            is_list(result) ->
              Enum.map(result, fn item ->
                if AST.is_element_node?(item),
                  do: evaluate_element_props(item, eval_ctx),
                  else: item
              end)

            is_reactive_assign?(result) and not reactive? ->
              context.get_state.(result.target)

            true ->
              result
          end
        end

      AST.is_element_node?(value) ->
        evaluate_element_props(value, eval_ctx)

      is_action_plan?(value) ->
        value

      true ->
        needs_eval? =
          Enum.any?(value, fn
            {"__keys__", _} -> false
            {_k, v} -> is_map(v) or is_list(v)
          end)

        if needs_eval? do
          Map.new(value, fn
            {"__keys__", keys} -> {"__keys__", keys}
            {k, v} -> {k, evaluate_prop_value(v, eval_ctx, schema_ctx, reactive?)}
          end)
        else
          value
        end
    end
  end

  defp evaluate_prop_core_inline(nil, _context, _schema_ctx, _reactive?), do: nil

  defp evaluate_prop_core_inline(value, _context, _schema_ctx, _reactive?)
       when not is_map(value) and not is_list(value) do
    value
  end

  defp evaluate_prop_core_inline(value, context, schema_ctx, reactive?) when is_list(value) do
    Enum.map(value, fn v -> evaluate_prop_inline(v, context, schema_ctx, reactive?) end)
  end

  defp evaluate_prop_core_inline(value, context, schema_ctx, reactive?) when is_map(value) do
    cond do
      AST.is_ast_node?(value) ->
        if value.k == :state_ref and reactive? do
          %{
            __reactive: "assign",
            target: value.n,
            expr: %{k: :state_ref, n: "$value"}
          }
        else
          result = evaluate(value, context, schema_ctx)

          cond do
            AST.is_element_node?(result) ->
              evaluate_element_inline(result, context, schema_ctx)

            is_list(result) ->
              Enum.map(result, fn item ->
                if AST.is_element_node?(item),
                  do: evaluate_element_inline(item, context, schema_ctx),
                  else: item
              end)

            is_reactive_assign?(result) and not reactive? ->
              context.get_state.(result.target)

            true ->
              result
          end
        end

      AST.is_element_node?(value) ->
        evaluate_element_inline(value, context, schema_ctx)

      is_action_plan?(value) ->
        value

      true ->
        needs_eval? =
          Enum.any?(value, fn
            {"__keys__", _} -> false
            {_k, v} -> is_map(v) or is_list(v)
          end)

        if needs_eval? do
          Map.new(value, fn
            {"__keys__", keys} -> {"__keys__", keys}
            {k, v} -> {k, evaluate_prop_inline(v, context, schema_ctx, reactive?)}
          end)
        else
          value
        end
    end
  end

  defp bindable_prop?(nil, _comp, _prop), do: false

  defp bindable_prop?(%{cat: %{bindable: bindable}}, comp, prop) when is_map(bindable) do
    case Map.get(bindable, comp) do
      %MapSet{} = set -> MapSet.member?(set, prop)
      list when is_list(list) -> prop in list
      _ -> false
    end
  end

  defp bindable_prop?(_, _, _), do: false

  defp record_runtime_error(errors_ref, err) do
    :ets.insert(errors_ref, {:err, err})
  end

  # ── Function & Action Helpers ────────────────────────────────────────────

  defp evaluate_args(node, context, params) do
    named = Map.get(node, :mapped_props) || Materialize.name_args(node.args, params)
    Map.new(named, fn {k, ast_val} -> {k, evaluate(ast_val, context)} end)
  end

  defp call_args(node, context, params_schema) do
    props = Map.get(params_schema, "properties", %{})
    required = Map.get(params_schema, "required", [])
    names = Schema.ordered_keys(props)
    params = Enum.map(names, &%{name: &1, required: false})
    args = evaluate_args(node, context, params)

    Enum.reduce(args, %{}, fn {k, v}, acc ->
      if v == nil and k not in required do
        acc
      else
        Map.put(acc, k, v)
      end
    end)
  end

  defp misses_required?(args, params_schema) do
    required = Map.get(params_schema, "required", [])
    props = Map.get(params_schema, "properties", %{})

    Enum.any?(required, fn key ->
      Map.get(args, key) == nil and
        Schema.get_schema_default_value(Map.get(props, key)) == :undefined
    end)
  end

  defp check_value(value, schema, name, path, context, strict) do
    ctx = %{
      errors: [],
      partial: false,
      current_statement_id: nil,
      cat: nil
    }

    {checked, ctx} = Schema.validate_schema_value(value, schema, name, path, ctx)

    if ctx.errors != [] do
      Enum.each(ctx.errors, fn e -> report_ctx_error(context, "@#{name}: #{e.message}") end)
    end

    if strict and ctx.errors != [] do
      :invalid
    else
      checked
    end
  end

  defp call_function(name, def_fn, node, context) do
    params_schema = Map.get(def_fn, "params") || Map.get(def_fn, :params) || %{}
    returns_schema = Map.get(def_fn, "returns") || Map.get(def_fn, :returns)
    fn_impl = Map.get(def_fn, :fn) || Map.get(def_fn, "fn")
    raw = call_args(node, context, params_schema)

    if misses_required?(raw, params_schema) do
      nil
    else
      case check_value(raw, params_schema, name, "", context, false) do
        :invalid ->
          nil

        {:ok, args} ->
          try do
            res = if is_function(fn_impl, 1), do: fn_impl.(args), else: nil

            if returns_schema == nil do
              res
            else
              case check_value(res, returns_schema, name, "/returns", context, false) do
                :invalid -> nil
                {:ok, checked} -> checked
              end
            end
          rescue
            e ->
              report_ctx_error(context, "@#{name} threw: #{Exception.message(e)}")
              nil
          end
      end
    end
  end

  defp evaluate_action_call(%{name: "Action", args: args}, context) do
    list = if args != [], do: evaluate(hd(args), context), else: []
    flatten_plans(if is_list(list), do: list, else: [])
  end

  defp evaluate_action_call(%{name: name, args: args} = node, context) do
    def_info = Map.fetch!(Builtins.builtin_steps(), name)

    step =
      if Map.get(def_info, :lazy) == true do
        evaluate_lazy_step(name, args)
      else
        eval_args = evaluate_args(node, context, def_info.params)
        build_eager_step(name, eval_args)
      end

    %{steps: if(step != nil, do: [step], else: [])}
  end

  defp build_eager_step("ToAssistant", args) do
    msg = Builtins.to_js_string(Map.get(args, "message"))
    ctx_val = Map.get(args, "context")
    step = %{type: "continue_conversation", message: msg}
    if ctx_val != nil, do: Map.put(step, :context, ctx_val), else: step
  end

  defp build_eager_step("OpenUrl", args) do
    %{type: "open_url", url: Builtins.to_js_string(Map.get(args, "url"))}
  end

  defp build_eager_step(_, _), do: nil

  defp evaluate_lazy_step("Run", [%{k: :runtime_ref, n: n, ref_type: ref_type} | _]) do
    %{type: "run", statement_id: n, ref_type: ref_type}
  end

  defp evaluate_lazy_step("Set", [%{k: :state_ref, n: target}, value_ast | _]) do
    %{type: "set", target: target, value_ast: value_ast}
  end

  defp evaluate_lazy_step("Reset", args) do
    targets =
      args
      |> Enum.filter(&(&1.k == :state_ref))
      |> Enum.map(& &1.n)

    if targets == [], do: nil, else: %{type: "reset", targets: targets}
  end

  defp evaluate_lazy_step(_, _), do: nil

  defp flatten_plans(values) do
    steps =
      Enum.flat_map(values, fn v ->
        cond do
          is_action_plan?(v) -> v.steps
          is_map(v) and (Map.has_key?(v, :type) or Map.has_key?(v, "type")) -> [v]
          true -> []
        end
      end)

    own_steps(%{steps: steps})
  end

  # ── @Each Lazy Evaluation & Variable Substitution ────────────────────────

  defp evaluate_lazy_builtin("Each", args, context, schema_ctx) when length(args) >= 3 do
    arr = evaluate(Enum.at(args, 0), context)

    if not is_list(arr) do
      []
    else
      var_name =
        case Enum.at(args, 1) do
          %{k: :ref, n: n} -> n
          %{k: :str, v: v} -> v
          _ -> nil
        end

      if var_name == nil do
        []
      else
        template = Enum.at(args, 2)

        Enum.map(arr, fn item ->
          substituted = substitute_ref(template, var_name, item)

          child_ctx = %{
            context
            | resolve_ref: fn ref_name ->
                if ref_name == var_name, do: item, else: context.resolve_ref.(ref_name)
              end
          }

          res = evaluate(substituted, child_ctx, schema_ctx)

          if schema_ctx != nil and AST.is_element_node?(res) do
            evaluate_element_inline(res, child_ctx, schema_ctx)
          else
            res
          end
        end)
      end
    end
  end

  defp evaluate_lazy_builtin(_, _, _, _), do: nil

  defp substitute_ref(%{k: :ref, n: n} = node, var_name, value) do
    if n == var_name, do: AST.to_literal_ast(value), else: node
  end

  defp substitute_ref(%{k: :member, obj: obj, field: field} = node, var_name, value) do
    if AST.is_ast_node?(obj) do
      sub_obj = substitute_ref(obj, var_name, value)

      if sub_obj.k == :obj do
        case Enum.find(sub_obj.entries, fn {k, _} -> k == field end) do
          {_, entry_val} -> entry_val
          nil -> %{node | obj: sub_obj}
        end
      else
        %{node | obj: sub_obj}
      end
    else
      node
    end
  end

  defp substitute_ref(%{k: :index, obj: obj, index: idx} = node, var_name, value) do
    %{
      node
      | obj: if(AST.is_ast_node?(obj), do: substitute_ref(obj, var_name, value), else: obj),
        index: if(AST.is_ast_node?(idx), do: substitute_ref(idx, var_name, value), else: idx)
    }
  end

  defp substitute_ref(%{k: :bin_op, left: l, right: r} = node, var_name, value) do
    %{node | left: substitute_ref(l, var_name, value), right: substitute_ref(r, var_name, value)}
  end

  defp substitute_ref(%{k: :unary_op, operand: op} = node, var_name, value) do
    %{node | operand: substitute_ref(op, var_name, value)}
  end

  defp substitute_ref(%{k: :ternary, cond: c, then: t, else: e} = node, var_name, value) do
    %{
      node
      | cond: substitute_ref(c, var_name, value),
        then: substitute_ref(t, var_name, value),
        else: substitute_ref(e, var_name, value)
    }
  end

  defp substitute_ref(%{k: :arr, els: els} = node, var_name, value) do
    %{node | els: Enum.map(els, &substitute_ref(&1, var_name, value))}
  end

  defp substitute_ref(%{k: :obj, entries: entries} = node, var_name, value) do
    %{node | entries: Enum.map(entries, fn {k, v} -> {k, substitute_ref(v, var_name, value)} end)}
  end

  defp substitute_ref(%{k: :comp, args: args} = node, var_name, value) do
    new_args = Enum.map(args, &substitute_ref(&1, var_name, value))
    node = %{node | args: new_args}

    if mapped = Map.get(node, :mapped_props) do
      new_mapped = Map.new(mapped, fn {k, v} -> {k, substitute_ref(v, var_name, value)} end)
      Map.put(node, :mapped_props, new_mapped)
    else
      node
    end
  end

  defp substitute_ref(%{k: :assign, value: val} = node, var_name, value) do
    %{node | value: substitute_ref(val, var_name, value)}
  end

  defp substitute_ref(node, _var_name, _value), do: node

  # ── Conformance Canonical Summary ────────────────────────────────────────

  @spec evaluate_result(map(), map()) :: map()
  def evaluate_result(parse_result, opts \\ %{}) do
    cat = Map.get(opts, :cat)
    custom_fns = Map.get(opts, :functions, %{})
    state_store = Map.get(parse_result, :state_declarations, %{})

    functions_clean =
      (cat &&
         (Map.get(cat, :functions_clean) ||
            Map.delete(Map.get(cat, :functions_schema, %{}), "__keys__"))) ||
        %{}

    actions_clean =
      (cat &&
         (Map.get(cat, :actions_clean) ||
            Map.delete(Map.get(cat, :actions_schema, %{}), "__keys__"))) ||
        %{}

    functions =
      if map_size(custom_fns) == 0 do
        functions_clean
      else
        Map.new(functions_clean, fn {name, fn_spec} ->
          {name, Map.put(fn_spec, :fn, Map.get(custom_fns, name))}
        end)
      end

    action_params =
      (cat && Map.get(cat, :action_params)) ||
        Map.new(actions_clean, fn {name, act_spec} ->
          props = get_in(act_spec, ["params", "properties"]) || %{}
          {name, Schema.ordered_keys(props)}
        end)

    ctx = %{
      get_state: fn name -> Map.get(state_store, name) end,
      resolve_ref: fn _name -> nil end,
      functions: functions,
      actions: actions_clean
    }

    resolve_ref_fn =
      if parse_result.query_statements == [] and parse_result.mutation_statements == [] do
        ctx.resolve_ref
      else
        fn name ->
          q = Enum.find(parse_result.query_statements, &(&1.statement_id == name))

          cond do
            q != nil ->
              if q.defaults_ast != nil, do: evaluate(q.defaults_ast, ctx), else: nil

            Enum.any?(parse_result.mutation_statements, &(&1.statement_id == name)) ->
              %{"status" => "idle", "data" => nil, "error" => nil}

            true ->
              nil
          end
        end
      end

    ctx = %{ctx | resolve_ref: resolve_ref_fn}
    has_custom = map_size(functions) > 0 or map_size(actions_clean) > 0
    eval_ctx = %{ctx: ctx, cat: cat, store: state_store, has_custom: has_custom}

    {tree, runtime_errors} = evaluate_root(parse_result, eval_ctx)

    parser_error_objs =
      Enum.map(parse_result.meta.errors, fn e ->
        base = %{
          "source" => "parser",
          "code" => e.code,
          "statementId" => e.statement_id,
          "component" => e.component,
          "message" => e.message
        }

        base = if e.path != "", do: Map.put(base, "path", e.path), else: base
        if Map.has_key?(e, :severity), do: Map.put(base, "severity", e.severity), else: base
      end)

    runtime_error_objs =
      Enum.map(runtime_errors, fn e ->
        %{
          "source" => "runtime",
          "code" => e.code,
          "statementId" => Map.get(e, :statement_id),
          "component" => Map.get(e, :component),
          "message" => Map.get(e, :message)
        }
      end)

    error_objects = parser_error_objs ++ runtime_error_objs

    ev_fn = fn ast_node -> evaluate(ast_node, ctx) end

    %{
      "tree" => tree,
      "root" => summarize(tree, ev_fn, action_params),
      "errors" =>
        Enum.map(error_objects, fn e ->
          %{"code" => e["code"], "statementId" => e["statementId"]}
        end),
      "errorObjects" => error_objects,
      "unresolved" => parse_result.meta.unresolved,
      "orphans" => parse_result.meta.orphaned,
      "incomplete" => parse_result.meta.incomplete,
      "state" => Schema.strip_keys_meta(state_store)
    }
  end

  defp summarize(nil, _ev, _action_params), do: nil

  defp summarize(v, _ev, _action_params) when not is_map(v) and not is_list(v) do
    v
  end

  defp summarize(v, ev, action_params) when is_list(v) do
    Enum.map(v, &summarize(&1, ev, action_params))
  end

  defp summarize(%{type: "element", type_name: type_name, props: props}, ev, action_params) do
    summarized_props =
      Enum.reduce(props, %{}, fn {k, pv}, acc ->
        s = summarize(pv, ev, action_params)
        if s != nil, do: Map.put(acc, k, s), else: acc
      end)

    %{"type" => type_name, "props" => summarized_props}
  end

  defp summarize(%{steps: steps}, ev, action_params) when is_list(steps) do
    %{"actions" => Enum.map(steps, &summarize_action(&1, ev, action_params))}
  end

  defp summarize(%{__reactive: "assign", target: target}, _ev, _action_params) do
    %{"$binding" => target}
  end

  defp summarize(v, ev, action_params) when is_map(v) do
    v
    |> Map.delete("__keys__")
    |> Map.new(fn {k, pv} -> {to_string(k), summarize(pv, ev, action_params)} end)
  end

  defp summarize_action(%{type: "continue_conversation"} = s, ev, action_params) do
    msg = s.message

    args =
      if Map.has_key?(s, :context) and s.context != nil do
        [msg, summarize(s.context, ev, action_params)]
      else
        [msg]
      end

    %{"action" => "ToAssistant", "args" => args}
  end

  defp summarize_action(%{type: "open_url"} = s, _ev, _action_params) do
    %{"action" => "OpenUrl", "args" => [s.url]}
  end

  defp summarize_action(%{type: "set"} = s, ev, action_params) do
    val = summarize(ev.(s.value_ast), ev, action_params)
    %{"action" => "Set", "args" => [s.target, val]}
  end

  defp summarize_action(%{type: "reset"} = s, _ev, _action_params) do
    %{"action" => "Reset", "args" => s.targets}
  end

  defp summarize_action(%{type: "run"} = s, _ev, _action_params) do
    %{"action" => "Run", "args" => [s.statement_id]}
  end

  defp summarize_action(%{name: name, params: params}, ev, action_params) do
    keys = Map.get(action_params, name) || Schema.ordered_keys(params)
    args = Enum.map(keys, fn k -> summarize(Map.get(params, k), ev, action_params) end)
    %{"action" => name, "args" => args}
  end
end
