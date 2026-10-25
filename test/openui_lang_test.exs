defmodule OpenUILangTest do
  use ExUnit.Case, async: true

  alias OpenUILang.Schema

  @fixtures_dir System.get_env("OPENUI_FIXTURES_DIR") ||
                  Path.expand("../../openui/spec/fixtures/1.0", __DIR__)
  @fixtures_available? File.dir?(@fixtures_dir)

  @library_spec (if @fixtures_available? do
                   @fixtures_dir
                   |> Path.join("library.json")
                   |> File.read!()
                   |> OpenUILang.decode_json!()
                 else
                   %{
                     "components" => %{
                       "Stack" => %{
                         "description" => "Flex container",
                         "props" => %{
                           "type" => "object",
                           "properties" => %{
                             "__keys__" => ["children", "direction"],
                             "children" => %{"type" => "array", "items" => %{}},
                             "direction" => %{"type" => "string", "enum" => ["row", "column"]}
                           },
                           "required" => ["children"]
                         }
                       },
                       "Card" => %{
                         "description" => "Card container",
                         "props" => %{
                           "type" => "object",
                           "properties" => %{
                             "__keys__" => ["title", "children"],
                             "title" => %{"type" => "string"},
                             "children" => %{"type" => "array", "items" => %{}}
                           },
                           "required" => ["title", "children"]
                         }
                       },
                       "Text" => %{
                         "description" => "Text node",
                         "props" => %{
                           "type" => "object",
                           "properties" => %{
                             "__keys__" => ["content"],
                             "content" => %{"type" => "string"}
                           },
                           "required" => ["content"]
                         }
                       },
                       "Button" => %{
                         "description" => "Action button",
                         "props" => %{
                           "type" => "object",
                           "properties" => %{
                             "__keys__" => ["label", "action"],
                             "label" => %{"type" => "string"},
                             "action" => %{"$ref" => "#/$defs/ActionPlan"}
                           },
                           "required" => ["label"]
                         }
                       }
                     },
                     "root" => "Stack",
                     "functions" => %{
                       "Upper" => %{
                         "description" => "Convert string to uppercase",
                         "parameters" => %{
                           "type" => "object",
                           "properties" => %{
                             "__keys__" => ["text"],
                             "text" => %{"type" => "string"}
                           },
                           "required" => ["text"]
                         },
                         "returns" => %{"type" => "string"}
                       }
                     },
                     "actions" => %{
                       "CopyToClipboard" => %{
                         "description" => "Copy text to clipboard",
                         "params" => %{
                           "type" => "object",
                           "properties" => %{
                             "__keys__" => ["text"],
                             "text" => %{"type" => "string"}
                           },
                           "required" => ["text"]
                         }
                       }
                     }
                   }
                 end)
  @compiled_schema OpenUILang.compile_schema(@library_spec)
  defp custom_functions do
    %{
      "Upper" => fn args ->
        text = Map.get(args, "text")
        String.upcase(if text == nil, do: "", else: to_string(text))
      end
    }
  end

  @optional_keys ["state", "statements", "errorObjects"]

  # Discover all fixture cases at compile time when external conformance fixtures are present
  @fixture_cases (if @fixtures_available? do
                    for area <- File.ls!(@fixtures_dir) |> Enum.sort(),
                        area_path = Path.join(@fixtures_dir, area),
                        File.dir?(area_path),
                        case_name <- File.ls!(area_path) |> Enum.sort(),
                        case_path = Path.join(area_path, case_name),
                        File.dir?(case_path) do
                      {"#{area}/#{case_name}", case_path}
                    end
                  else
                    []
                  end)

  describe "OpenUI 1.0 Conformance Suite" do
    for {id, case_path} <- @fixture_cases do
      @tag fixture: id
      test "conformance: #{id}" do
        id = unquote(id)
        case_path = unquote(case_path)

        files =
          File.ls!(case_path)
          |> Map.new(fn f -> {f, File.read!(Path.join(case_path, f))} end)

        diffs =
          if Map.has_key?(files, "validation.json") do
            run_validation_case(files)
          else
            run_program_case(id, files)
          end

        assert diffs == [],
               "Conformance fixture #{id} failed:\n  " <> Enum.join(diffs, "\n  ")
      end
    end
  end

  describe "OpenUILang features beyond fixtures" do
    test "@Each iterates array and substitutes loop variable in template and actions" do
      code = """
      $selected = ""
      rows = [{id: "t1", title: "Login bug"}, {id: "t2", title: "Timeout"}]
      root = Stack(@Each(rows, "t", Card(t.title, [Button("Select", @Set($selected, t.id))])))
      """

      res = OpenUILang.parse(code, @compiled_schema)
      evaluated = OpenUILang.evaluate_result(res, %{cat: @compiled_schema})

      assert evaluated["errors"] == []

      assert evaluated["root"] == %{
               "type" => "Stack",
               "props" => %{
                 "children" => [
                   %{
                     "type" => "Card",
                     "props" => %{
                       "title" => "Login bug",
                       "children" => [
                         %{
                           "type" => "Button",
                           "props" => %{
                             "label" => "Select",
                             "action" => %{
                               "actions" => [
                                 %{"action" => "Set", "args" => ["$selected", "t1"]}
                               ]
                             }
                           }
                         }
                       ]
                     }
                   },
                   %{
                     "type" => "Card",
                     "props" => %{
                       "title" => "Timeout",
                       "children" => [
                         %{
                           "type" => "Button",
                           "props" => %{
                             "label" => "Select",
                             "action" => %{
                               "actions" => [
                                 %{"action" => "Set", "args" => ["$selected", "t2"]}
                               ]
                             }
                           }
                         }
                       ]
                     }
                   }
                 ]
               }
             }
    end

    test "message protocol build_message and parse_message roundtrip" do
      msg =
        OpenUILang.build_message(%{
          content: "root = Stack([Text(\"Hello\")])",
          context: %{"user" => "alice"},
          attributes: %{"library" => "tui"},
          end: true
        })

      parsed = OpenUILang.parse_message(msg)
      assert parsed.content == "root = Stack([Text(\"Hello\")])"
      assert parsed.context == %{"user" => "alice"}
      assert parsed.attributes == %{"library" => "tui"}
      assert parsed.end == true
    end

    test "generate_system_prompt emits component and function signatures" do
      prompt = OpenUILang.generate_system_prompt(@library_spec)
      assert prompt =~ "root = Stack(...)"
      assert prompt =~ "Stack(children: any[], direction?: \"row\" | \"column\")"
      assert prompt =~ "@Upper(text: string) → string"
      assert prompt =~ "@CopyToClipboard(text: string)"
    end

    test "demux separates conversational prose from fenced or unfenced openui code" do
      mixed = """
      Here is the cluster health overview you requested:

      ```openui
      root = Panel("Cluster Health", [kpis], "info")
      kpis = Row([Stat("CPU", "68%")])
      ```

      Let me know if you want to scale replicas.
      """

      res = OpenUILang.demux(mixed)
      assert res.prose =~ "Here is the cluster health overview"
      assert res.prose =~ "Let me know if you want to scale replicas."
      assert res.code =~ ~s|root = Panel("Cluster Health", [kpis], "info")|
    end

    test "parse_symbols extracts tuple AST with :ref and :var nodes for TUI resolution" do
      src = """
      root = Panel("Cluster", [kpis, scale_form], "info")
      $target_env = "prod-us"
      kpis = Row([cpu_stat])
      scale_form = Select("Environment", $target_env, ["prod-us", "staging"])
      """

      syms = OpenUILang.parse_symbols(src)
      assert syms["$target_env"] == "prod-us"

      assert syms["root"] ==
               {"Panel", ["Cluster", [{:ref, "kpis"}, {:ref, "scale_form"}], "info"]}

      assert syms["kpis"] == {"Row", [[{:ref, "cpu_stat"}]]}

      assert syms["scale_form"] ==
               {"Select", ["Environment", {:var, "$target_env"}, ["prod-us", "staging"]]}

      multiline_unfenced = """
      root = Dashboard("Memcached Telemetry", "Primary", [
        Alert("info", "Operating normally"),
        Row([
          Stat("Get Ops", "2.5M", "+100k", Sparkline([2.3M, 2.4M, 2.5M], "info"))
        ])
      ])
      """

      demuxed = OpenUILang.demux(multiline_unfenced)
      assert demuxed.prose == ""
      assert demuxed.code =~ "Alert(\"info\""
      assert demuxed.code =~ "Sparkline([2.3M"
    end
  end

  # ── Conformance Runner Helpers ───────────────────────────────────────────

  defp run_validation_case(files) do
    %{"cases" => cases} = OpenUILang.decode_json!(files["validation.json"])

    cases
    |> Enum.with_index()
    |> Enum.flat_map(fn {%{"rules" => rules, "value" => value, "valid" => valid}, i} ->
      clean_val = Schema.strip_keys_meta(value)
      err = OpenUILang.validate_rules(clean_val, rules)

      if err == nil == valid do
        []
      else
        ["case #{i}: expected valid=#{valid}, got error=#{inspect(err)}"]
      end
    end)
  end

  defp run_program_case(id, files) do
    expected = OpenUILang.decode_json!(files["expected.json"]) |> Schema.strip_keys_meta()

    cond do
      Map.has_key?(files, "chunks.json") ->
        chunks = OpenUILang.decode_json!(files["chunks.json"])
        sp = OpenUILang.stream_parser(@compiled_schema)

        sp =
          chunks
          |> Enum.with_index()
          |> Enum.reduce(sp, fn {chunk, idx}, acc_sp ->
            {_res, next_sp} = OpenUILang.push_chunk(acc_sp, chunk, idx == length(chunks) - 1)
            next_sp
          end)

        {stream_res, _} = OpenUILang.Parser.get_result(sp, true)
        batch_res = OpenUILang.parse(Enum.join(chunks, ""), @compiled_schema)

        stream_diffs =
          check_result(id, expected, stream_res, nil) |> Enum.map(&"streamed #{&1}")

        batch_diffs = check_result(id, expected, batch_res, nil) |> Enum.map(&"batch #{&1}")
        stream_diffs ++ batch_diffs

      Map.has_key?(files, "patch.oui") ->
        merged = OpenUILang.merge_statements(files["input.oui"], files["patch.oui"])

        statements =
          merged
          |> String.split("\n")
          |> Enum.flat_map(fn line ->
            case Regex.run(~r/^(\$?\w+)\s*=(?!=)/, line) do
              [_, name] -> [name]
              _ -> []
            end
          end)

        check_result(
          id,
          expected,
          OpenUILang.parse(merged, @compiled_schema),
          statements
        )

      true ->
        check_result(
          id,
          expected,
          OpenUILang.parse(files["input.oui"], @compiled_schema),
          nil
        )
    end
  end

  defp check_result(id, expected, parse_result, statements) do
    actual =
      OpenUILang.evaluate_result(parse_result, %{
        cat: @compiled_schema,
        functions: custom_functions()
      })
      |> Map.put("statements", statements)

    keys = [
      "root",
      "errors",
      "unresolved",
      "orphans",
      "incomplete",
      "state",
      "statements",
      "errorObjects"
    ]

    diffs =
      Enum.flat_map(keys, fn k ->
        if Map.has_key?(expected, k) or k not in @optional_keys do
          want = Map.get(expected, k)
          got = Map.get(actual, k)

          if compare_field(k, want, got) do
            []
          else
            ["#{k}: expected #{inspect(want)}, got #{inspect(got)}"]
          end
        else
          []
        end
      end)

    if String.contains?(id, "-roundtrip-") and actual["tree"] != nil do
      text = OpenUILang.json_to_openui(actual["tree"], @compiled_schema)

      again =
        OpenUILang.parse(text, @compiled_schema)
        |> OpenUILang.evaluate_result(%{cat: @compiled_schema, functions: custom_functions()})
        |> Map.get("root")

      if again != expected["root"] do
        diffs ++ ["roundtrip: #{inspect(text)} parses to #{inspect(again)}"]
      else
        diffs
      end
    else
      diffs
    end
  end

  defp compare_field("errors", want, got) when is_list(want) and is_list(got) do
    length(want) == length(got) and claims?(want, got)
  end

  defp compare_field("errorObjects", want, got) when is_list(want) and is_list(got) do
    claims?(want, got)
  end

  defp compare_field(k, want, got) when k in ["unresolved", "orphans"] do
    Enum.sort(Enum.uniq(want || [])) == Enum.sort(Enum.uniq(got || []))
  end

  defp compare_field(_k, want, got) do
    want == got
  end

  defp claims?(expected_list, actual_list) do
    sorted_expected = Enum.sort_by(expected_list, &(-map_size(&1)))

    Enum.reduce_while(sorted_expected, {:ok, actual_list}, fn exp, {:ok, pool} ->
      match_idx =
        Enum.find_index(pool, fn act ->
          Enum.all?(exp, fn {k, v} -> Map.get(act, k) == v end)
        end)

      if match_idx != nil do
        {:cont, {:ok, List.delete_at(pool, match_idx)}}
      else
        {:halt, :error}
      end
    end)
    |> case do
      {:ok, _} -> true
      :error -> false
    end
  end
end
