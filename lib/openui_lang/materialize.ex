defmodule OpenUILang.Materialize do
  @moduledoc false

  alias OpenUILang.{AST, Builtins, Schema}

  @spec contains_dynamic_value?(term()) :: boolean()
  def contains_dynamic_value?(nil), do: false
  def contains_dynamic_value?(v) when not is_map(v) and not is_list(v), do: false

  def contains_dynamic_value?(v) when is_list(v) do
    Enum.any?(v, &contains_dynamic_value?/1)
  end

  def contains_dynamic_value?(v) when is_map(v) do
    cond do
      AST.is_ast_node?(v) ->
        true

      AST.is_element_node?(v) ->
        Map.get(v, :has_dynamic_props, false)

      is_list(Map.get(v, :steps)) or is_list(Map.get(v, "steps")) ->
        true

      true ->
        v |> Map.values() |> Enum.any?(&contains_dynamic_value?/1)
    end
  end

  @spec name_args([map()], [map()]) :: map()
  def name_args(args, params) do
    Enum.zip(params, args)
    |> Map.new(fn {p, arg} -> {p.name, arg} end)
  end

  @spec map_call_args(String.t(), [map()], map(), map()) :: {map() | nil, map()}
  def map_call_args(name, args, def_info, ctx) do
    params = def_info.params

    ctx =
      if length(args) > length(params) do
        Schema.push_validation_issue(ctx, name, "", %{
          code: "excess-args",
          declared: length(params),
          got: length(args)
        })
      else
        ctx
      end

    mapped = name_args(args, params)
    errors_before = length(ctx.errors)

    {mapped, invalid, ctx} =
      Enum.reduce(params, {mapped, false, ctx}, fn p, {acc_map, inv, acc_ctx} ->
        arg = Map.get(acc_map, p.name)

        lit_res =
          if arg != nil do
            AST.literal_value(arg)
          else
            {:ok, :undefined}
          end

        case lit_res do
          :error ->
            {acc_map, inv, acc_ctx}

          {:ok, val} when val in [nil, :undefined] ->
            if not p.required or p.default_value != :undefined do
              {acc_map, inv, acc_ctx}
            else
              code = if arg != nil, do: "null-required", else: "missing-required"

              acc_ctx =
                Schema.push_validation_issue(acc_ctx, name, "/#{p.name}", %{
                  code: code,
                  signature: Schema.build_params_signature(name, params)
                })

              {acc_map, true, acc_ctx}
            end

          {:ok, val} ->
            {res, acc_ctx} =
              Schema.validate_schema_value(val, p.schema, name, "/#{p.name}", acc_ctx)

            case res do
              {:ok, ^val} ->
                {acc_map, inv, acc_ctx}

              {:ok, next_val} ->
                {Map.put(acc_map, p.name, AST.to_literal_ast(next_val)), inv, acc_ctx}

              :invalid ->
                case Schema.resolve_invalid_value(p.required, p.default_value) do
                  {:ok, default_val} ->
                    {Map.put(acc_map, p.name, AST.to_literal_ast(default_val)), inv, acc_ctx}

                  :omit ->
                    {Map.delete(acc_map, p.name), inv, acc_ctx}

                  :invalid ->
                    {acc_map, true, acc_ctx}
                end
            end
        end
      end)

    invalid =
      if def_info.kind == :action and length(ctx.errors) > errors_before do
        true
      else
        invalid
      end

    {if(invalid, do: nil, else: mapped), ctx}
  end

  @spec name_raw_call_args([map()], map(), String.t()) :: {[map()], map()}
  def name_raw_call_args(args, ctx, statement_id) do
    prev_id = ctx.current_statement_id
    ctx = %{ctx | current_statement_id: statement_id}

    {rev_args, ctx} =
      Enum.reduce(args, {[], ctx}, fn arg, {acc_args, acc_ctx} ->
        {named_arg, acc_ctx} = name_raw_node(arg, acc_ctx)
        {[named_arg | acc_args], acc_ctx}
      end)

    {Enum.reverse(rev_args), %{ctx | current_statement_id: prev_id}}
  end

  defp name_raw_node(%{k: :comp, name: name, args: args} = node, ctx) do
    {new_args, ctx} =
      Enum.reduce(args, {[], ctx}, fn a, {acc, c} ->
        {na, c} = name_raw_node(a, c)
        {[na | acc], c}
      end)

    new_args = Enum.reverse(new_args)
    node = %{node | args: new_args}
    call_defs = get_call_defs(ctx.cat)
    def_info = Map.get(call_defs, name)

    if def_info == nil or Map.get(def_info, :lazy) == true do
      {node, ctx}
    else
      {checked, ctx} =
        if Map.get(def_info, :builtin) == true do
          {nil, ctx}
        else
          map_call_args(name, new_args, def_info, ctx)
        end

      mapped_props = checked || name_args(new_args, def_info.params)
      {Map.put(node, :mapped_props, mapped_props), ctx}
    end
  end

  defp name_raw_node(%{k: :arr, els: els} = node, ctx) do
    {new_els, ctx} =
      Enum.reduce(els, {[], ctx}, fn e, {acc, c} ->
        {ne, c} = name_raw_node(e, c)
        {[ne | acc], c}
      end)

    {%{node | els: Enum.reverse(new_els)}, ctx}
  end

  defp name_raw_node(%{k: :obj, entries: entries} = node, ctx) do
    {new_entries, ctx} =
      Enum.reduce(entries, {[], ctx}, fn {k, v}, {acc, c} ->
        {nv, c} = name_raw_node(v, c)
        {[{k, nv} | acc], c}
      end)

    {%{node | entries: Enum.reverse(new_entries)}, ctx}
  end

  defp name_raw_node(%{k: :bin_op, left: l, right: r} = node, ctx) do
    {nl, ctx} = name_raw_node(l, ctx)
    {nr, ctx} = name_raw_node(r, ctx)
    {%{node | left: nl, right: nr}, ctx}
  end

  defp name_raw_node(%{k: :unary_op, operand: op} = node, ctx) do
    {nop, ctx} = name_raw_node(op, ctx)
    {%{node | operand: nop}, ctx}
  end

  defp name_raw_node(%{k: :ternary, cond: c, then: t, else: e} = node, ctx) do
    {nc, ctx} = name_raw_node(c, ctx)
    {nt, ctx} = name_raw_node(t, ctx)
    {ne, ctx} = name_raw_node(e, ctx)
    {%{node | cond: nc, then: nt, else: ne}, ctx}
  end

  defp name_raw_node(%{k: :member, obj: obj} = node, ctx) do
    {nobj, ctx} = name_raw_node(obj, ctx)
    {%{node | obj: nobj}, ctx}
  end

  defp name_raw_node(%{k: :index, obj: obj, index: idx} = node, ctx) do
    {nobj, ctx} = name_raw_node(obj, ctx)
    {nidx, ctx} = name_raw_node(idx, ctx)
    {%{node | obj: nobj, index: nidx}, ctx}
  end

  defp name_raw_node(node, ctx), do: {node, ctx}

  @spec materialize_expr(map(), map()) :: {map(), map()}
  def materialize_expr(node, ctx) do
    materialize_expr_internal(node, ctx, MapSet.new())
  end

  defp materialize_expr_internal(%{k: :ref, n: n} = node, ctx, scoped_refs) do
    if MapSet.member?(scoped_refs, n) do
      {node, ctx}
    else
      resolve_ref(n, ctx, :expr)
    end
  end

  defp materialize_expr_internal(%{k: :ph} = node, ctx, _scoped_refs), do: {node, ctx}

  defp materialize_expr_internal(%{k: :comp, name: name, args: args} = node, ctx, scoped_refs) do
    if Map.get(node, :fn) == true and not runtime_call?(name, ctx) do
      ctx = Schema.push_validation_issue(ctx, name, "", %{code: "unknown-function"})
      {%{k: :null}, ctx}
    else
      case materialize_lazy_builtin(node, ctx, scoped_refs) do
        {:ok, lazy_node, ctx} ->
          {lazy_node, ctx}

        :none ->
          if runtime_call?(name, ctx) do
            materialize_call(node, ctx, fn a, c ->
              materialize_expr_internal(a, c, scoped_refs)
            end)
          else
            {recursed_args, ctx} =
              Enum.reduce(args, {[], ctx}, fn a, {acc, c} ->
                {na, c} = materialize_expr_internal(a, c, scoped_refs)
                {[na | acc], c}
              end)

            recursed_args = Enum.reverse(recursed_args)
            comps = if ctx.cat, do: ctx.cat.components, else: %{}

            case Map.get(comps, name) do
              %{params: params} ->
                mapped_props = name_args(recursed_args, params)
                {Map.put(%{node | args: recursed_args}, :mapped_props, mapped_props), ctx}

              nil ->
                ctx =
                  Schema.push_validation_issue(ctx, name, "", %{
                    code: "unknown-component",
                    available: Map.keys(comps)
                  })

                {%{node | args: recursed_args}, ctx}
            end
          end
      end
    end
  end

  defp materialize_expr_internal(%{k: :arr, els: els} = node, ctx, scoped_refs) do
    {new_els, ctx} =
      Enum.reduce(els, {[], ctx}, fn e, {acc, c} ->
        {ne, c} = materialize_expr_internal(e, c, scoped_refs)
        {[ne | acc], c}
      end)

    {%{node | els: Enum.reverse(new_els)}, ctx}
  end

  defp materialize_expr_internal(%{k: :obj, entries: entries} = node, ctx, scoped_refs) do
    {new_entries, ctx} =
      Enum.reduce(entries, {[], ctx}, fn {k, v}, {acc, c} ->
        {nv, c} = materialize_expr_internal(v, c, scoped_refs)
        {[{k, nv} | acc], c}
      end)

    {%{node | entries: Enum.reverse(new_entries)}, ctx}
  end

  defp materialize_expr_internal(%{k: :bin_op, left: l, right: r} = node, ctx, scoped_refs) do
    {nl, ctx} = materialize_expr_internal(l, ctx, scoped_refs)
    {nr, ctx} = materialize_expr_internal(r, ctx, scoped_refs)
    {%{node | left: nl, right: nr}, ctx}
  end

  defp materialize_expr_internal(%{k: :unary_op, operand: op} = node, ctx, scoped_refs) do
    {nop, ctx} = materialize_expr_internal(op, ctx, scoped_refs)
    {%{node | operand: nop}, ctx}
  end

  defp materialize_expr_internal(
         %{k: :ternary, cond: c, then: t, else: e} = node,
         ctx,
         scoped_refs
       ) do
    {nc, ctx} = materialize_expr_internal(c, ctx, scoped_refs)
    {nt, ctx} = materialize_expr_internal(t, ctx, scoped_refs)
    {ne, ctx} = materialize_expr_internal(e, ctx, scoped_refs)
    {%{node | cond: nc, then: nt, else: ne}, ctx}
  end

  defp materialize_expr_internal(%{k: :member, obj: obj} = node, ctx, scoped_refs) do
    {nobj, ctx} = materialize_expr_internal(obj, ctx, scoped_refs)
    {%{node | obj: nobj}, ctx}
  end

  defp materialize_expr_internal(%{k: :index, obj: obj, index: idx} = node, ctx, scoped_refs) do
    {nobj, ctx} = materialize_expr_internal(obj, ctx, scoped_refs)
    {nidx, ctx} = materialize_expr_internal(idx, ctx, scoped_refs)
    {%{node | obj: nobj, index: nidx}, ctx}
  end

  defp materialize_expr_internal(%{k: :assign, value: val} = node, ctx, scoped_refs) do
    {nval, ctx} = materialize_expr_internal(val, ctx, scoped_refs)
    {%{node | value: nval}, ctx}
  end

  defp materialize_expr_internal(node, ctx, _scoped_refs), do: {node, ctx}

  @spec materialize_value(map(), map()) :: {term(), map()}
  def materialize_value(%{k: :ref, n: n}, ctx), do: resolve_ref(n, ctx, :value)
  def materialize_value(%{k: :str, v: v}, ctx), do: {v, ctx}
  def materialize_value(%{k: :num, v: v}, ctx), do: {v, ctx}
  def materialize_value(%{k: :bool, v: v}, ctx), do: {v, ctx}
  def materialize_value(%{k: :null}, ctx), do: {nil, ctx}
  def materialize_value(%{k: :ph}, ctx), do: {nil, ctx}

  def materialize_value(%{k: :arr, els: els}, ctx) do
    {rev_items, ctx} =
      Enum.reduce(els, {[], ctx}, fn e, {acc, c} ->
        if e.k == :ph do
          {acc, c}
        else
          {val, c} = materialize_value(e, c)

          if val == nil and e.k in [:comp, :ref] do
            {acc, c}
          else
            {[val | acc], c}
          end
        end
      end)

    {Enum.reverse(rev_items), ctx}
  end

  def materialize_value(%{k: :obj, entries: entries}, ctx) do
    {rev_pairs, ctx} =
      Enum.reduce(entries, {[], ctx}, fn {k, v}, {acc, c} ->
        {val, c} = materialize_value(v, c)
        {[{k, val} | acc], c}
      end)

    pairs = Enum.reverse(rev_pairs)
    keys = Enum.map(pairs, &elem(&1, 0)) |> Enum.uniq()
    map = Map.new(pairs) |> Map.put("__keys__", keys)
    {map, ctx}
  end

  def materialize_value(%{k: :comp, name: name, args: args} = node, ctx) do
    cond do
      Map.get(node, :fn) == true and not runtime_call?(name, ctx) ->
        ctx = Schema.push_validation_issue(ctx, name, "", %{code: "unknown-function"})
        {nil, ctx}

      Builtins.is_reserved_call?(name) ->
        ctx = Schema.push_validation_issue(ctx, name, "", %{code: "inline-reserved"})
        {nil, ctx}

      runtime_call?(name, ctx) ->
        case materialize_lazy_builtin(node, ctx, MapSet.new()) do
          {:ok, lazy_node, ctx} ->
            {lazy_node, ctx}

          :none ->
            materialize_call(node, ctx, fn a, c -> materialize_expr(a, c) end)
        end

      true ->
        comps = if ctx.cat, do: ctx.cat.components, else: %{}

        case Map.get(comps, name) do
          nil ->
            ctx =
              Schema.push_validation_issue(ctx, name, "", %{
                code: "unknown-component",
                available: Map.keys(comps)
              })

            {nil, ctx}

          %{params: params} ->
            materialize_component(name, args, params, ctx)
        end
    end
  end

  def materialize_value(node, ctx) do
    if AST.is_runtime_expr?(node) do
      materialize_expr(node, ctx)
    else
      {node, ctx}
    end
  end

  defp materialize_component(name, args, params, ctx) do
    {props, drop_component, ctx} =
      params
      |> Enum.zip(args)
      |> Enum.reduce({%{}, false, ctx}, fn {param, arg_ast}, {acc_props, drop?, acc_ctx} ->
        {val, acc_ctx} = materialize_value(arg_ast, acc_ctx)
        acc_props = Map.put(acc_props, param.name, val)

        if param.schema == nil do
          {acc_props, drop?, acc_ctx}
        else
          {res, acc_ctx} =
            Schema.validate_schema_value(val, param.schema, name, "/#{param.name}", acc_ctx)

          case res do
            {:ok, next_val} ->
              {Map.put(acc_props, param.name, next_val), drop?, acc_ctx}

            :invalid ->
              case Schema.resolve_invalid_value(param.required, param.default_value) do
                {:ok, default_val} ->
                  {Map.put(acc_props, param.name, default_val), drop?, acc_ctx}

                :omit ->
                  {Map.delete(acc_props, param.name), drop?, acc_ctx}

                :invalid ->
                  {acc_props, true, acc_ctx}
              end
          end
        end
      end)

    ctx =
      if length(args) > length(params) do
        Schema.push_validation_issue(ctx, name, "", %{
          code: "excess-args",
          declared: length(params),
          got: length(args)
        })
      else
        ctx
      end

    missing_required =
      Enum.filter(params, fn p ->
        p.required and (not Map.has_key?(props, p.name) or Map.get(props, p.name) == nil)
      end)

    {props, still_invalid} =
      Enum.reduce(missing_required, {props, []}, fn p, {acc_props, inv_list} ->
        case p.default_value do
          {:ok, def_val} -> {Map.put(acc_props, p.name, def_val), inv_list}
          :undefined -> {acc_props, [p | inv_list]}
        end
      end)

    still_invalid = Enum.reverse(still_invalid)

    cond do
      still_invalid != [] ->
        ctx =
          Enum.reduce(still_invalid, ctx, fn p, acc_ctx ->
            code = if Map.has_key?(props, p.name), do: "null-required", else: "missing-required"

            Schema.push_validation_issue(acc_ctx, name, "/#{p.name}", %{
              code: code,
              signature: Schema.build_params_signature(name, params)
            })
          end)

        {nil, ctx}

      drop_component ->
        {nil, ctx}

      true ->
        has_dynamic = props |> Map.values() |> Enum.any?(&contains_dynamic_value?/1)

        el = %{
          type: "element",
          type_name: name,
          props: props,
          partial: ctx.partial,
          has_dynamic_props: has_dynamic
        }

        {el, ctx}
    end
  end

  defp resolve_ref(name, ctx, mode) do
    cond do
      MapSet.member?(ctx.visited, name) ->
        ctx = %{ctx | unres: [name | ctx.unres]}
        {if(mode == :expr, do: %{k: :ph, n: name}, else: nil), ctx}

      not Map.has_key?(ctx.syms, name) ->
        ctx = %{ctx | unres: [name | ctx.unres]}
        {if(mode == :expr, do: %{k: :ph, n: name}, else: nil), ctx}

      true ->
        target = Map.fetch!(ctx.syms, name)
        ctx = %{ctx | unreached: MapSet.delete(ctx.unreached, name)}

        if target.k == :comp and Builtins.is_reserved_call?(target.name) do
          ref_type = if target.name == "Mutation", do: :mutation, else: :query
          {%{k: :runtime_ref, n: name, ref_type: ref_type}, ctx}
        else
          cache_key =
            if mode == :value and is_map(Map.get(ctx, :mat_cache)) do
              {:value, name, ctx.partial}
            else
              nil
            end

          case cache_key && Map.get(ctx.mat_cache, cache_key) do
            %{result: cached_res, errors: cached_errs, unres: cached_unres, reached: cached_reached} ->
              ctx = %{
                ctx
                | errors: cached_errs ++ ctx.errors,
                  unres: cached_unres ++ ctx.unres,
                  unreached: MapSet.difference(ctx.unreached, cached_reached)
              }

              {cached_res, ctx}

            nil ->
              prev_id = ctx.current_statement_id
              prev_errors = ctx.errors
              prev_unres = ctx.unres
              prev_unreached = ctx.unreached

              ctx =
                if cache_key != nil do
                  %{
                    ctx
                    | visited: MapSet.put(ctx.visited, name),
                      current_statement_id: name,
                      errors: [],
                      unres: []
                  }
                else
                  %{
                    ctx
                    | visited: MapSet.put(ctx.visited, name),
                      current_statement_id: name
                  }
                end

              {result, ctx} =
                if mode == :value do
                  materialize_value(target, ctx)
                else
                  materialize_expr(target, ctx)
                end

              result =
                if mode == :value and AST.is_element_node?(result) do
                  Map.put(result, :statement_id, name)
                else
                  result
                end

              ctx =
                if cache_key != nil do
                  sub_errors = ctx.errors
                  sub_unres = ctx.unres
                  reached = MapSet.difference(prev_unreached, ctx.unreached) |> MapSet.put(name)

                  next_cache =
                    if sub_unres == [] and
                         (ctx[:pending_ids] == nil or
                            (not MapSet.member?(ctx.pending_ids, name) and
                               MapSet.disjoint?(reached, ctx.pending_ids))) do
                      Map.put(ctx.mat_cache, cache_key, %{
                        result: result,
                        errors: sub_errors,
                        unres: sub_unres,
                        reached: reached
                      })
                    else
                      ctx.mat_cache
                    end

                  %{
                    ctx
                    | visited: MapSet.delete(ctx.visited, name),
                      current_statement_id: prev_id,
                      errors: sub_errors ++ prev_errors,
                      unres: sub_unres ++ prev_unres,
                      mat_cache: next_cache
                  }
                else
                  %{
                    ctx
                    | visited: MapSet.delete(ctx.visited, name),
                      current_statement_id: prev_id
                  }
                end

              {result, ctx}
          end
        end
    end
  end

  defp get_call_defs(nil), do: Builtins.builtin_calls()
  defp get_call_defs(cat), do: Map.get(cat, :call_defs) || Builtins.builtin_calls()

  defp runtime_call?(name, ctx) do
    Map.has_key?(get_call_defs(ctx.cat), name) or Builtins.is_reserved_call?(name)
  end

  defp materialize_call(node, ctx, materialize_arg) do
    {args, ctx} =
      Enum.reduce(node.args, {[], ctx}, fn a, {acc, c} ->
        {na, c} = materialize_arg.(a, c)
        {[na | acc], c}
      end)

    args = Enum.reverse(args)
    def_info = Map.get(get_call_defs(ctx.cat), node.name)

    if def_info == nil or Map.get(def_info, :lazy) == true do
      {%{node | args: args}, ctx}
    else
      {mapped_props, ctx} =
        if Map.get(def_info, :builtin) == true do
          {name_args(args, def_info.params), ctx}
        else
          map_call_args(node.name, args, def_info, ctx)
        end

      cond do
        mapped_props != nil ->
          {Map.put(%{node | args: args}, :mapped_props, mapped_props), ctx}

        def_info.kind == :action ->
          {%{k: :comp, name: "Action", args: [%{k: :arr, els: []}]}, ctx}

        true ->
          {%{k: :null}, ctx}
      end
    end
  end

  defp materialize_lazy_builtin(%{k: :comp, name: name, args: args} = node, ctx, scoped_refs) do
    def_info = Map.get(get_call_defs(ctx.cat), name)

    if def_info != nil and def_info.kind == :function and Map.get(def_info, :lazy) == true and
         length(args) >= 3 do
      var_arg = Enum.at(args, 1)

      var_name =
        case var_arg do
          %{k: :ref, n: n} -> n
          %{k: :str, v: v} -> v
          _ -> nil
        end

      if var_name == nil do
        :none
      else
        next_scoped = MapSet.put(scoped_refs, var_name)

        {new_args, ctx} =
          args
          |> Enum.with_index()
          |> Enum.reduce({[], ctx}, fn {a, idx}, {acc, c} ->
            if idx == 1 do
              {[a | acc], c}
            else
              {na, c} = materialize_expr_internal(a, c, next_scoped)
              {[na | acc], c}
            end
          end)

        {:ok, %{node | args: Enum.reverse(new_args)}, ctx}
      end
    else
      :none
    end
  end
end
