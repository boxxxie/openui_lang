# Benchmark & Profiling Suite for OpenUILang (`openui_lang`)
# Run with:
#   mix run bench/profile_and_bench.exs
#   mix run bench/profile_and_bench.exs -- --profile

Mix.ensure_application!(:tools)

defmodule OpenUILang.Bench do
  @library_json File.read!(
                  Path.expand(
                    "../../openui/spec/fixtures/1.0/library.json",
                    __DIR__
                  )
                )

  def run do
    IO.puts("\n======================================================================")
    IO.puts("  OpenUILang 1.0 — Performance Benchmark & Profiling Suite")
    IO.puts("  Elixir #{System.version()} / OTP #{System.otp_release()} (#{:erlang.system_info(:system_architecture)})")
    IO.puts("======================================================================\n")

    raw_spec = OpenUILang.decode_json!(@library_json)
    schema = OpenUILang.compile_schema(raw_spec)

    small_src = build_small_program()
    medium_src = build_medium_program()
    large_src = build_large_program(100)
    patch_src = build_patch_program()
    mixed_chat_src = build_mixed_chat(medium_src)

    parsed_medium = OpenUILang.parse(medium_src, schema)
    evaluated_medium = OpenUILang.evaluate_result(parsed_medium, %{cat: schema})
    medium_chunks = chunk_string(medium_src, 32)
    large_chunks = chunk_string(large_src, 48)

    IO.puts("Workload Sizes:")
    IO.puts("  • Small Program   : #{byte_size(small_src)} bytes (6 statements)")
    IO.puts("  • Medium Program  : #{byte_size(medium_src)} bytes (24 statements, #{length(medium_chunks)}x 32B stream chunks)")
    IO.puts("  • Large Program   : #{byte_size(large_src)} bytes (~105 statements, #{length(large_chunks)}x 48B stream chunks)")
    IO.puts("")

    benchmarks = [
      {"1. decode_json! + compile_schema (library.json)", 500,
       fn ->
         spec = OpenUILang.decode_json!(@library_json)
         OpenUILang.compile_schema(spec)
       end},
      {"2. Lexer.tokenize (Medium 24 stmts)", 2_000,
       fn ->
         OpenUILang.Lexer.tokenize(medium_src)
       end},
      {"3. parse (Small 6 stmts)", 2_000,
       fn ->
         OpenUILang.parse(small_src, schema)
       end},
      {"4. parse (Medium 24 stmts)", 1_000,
       fn ->
         OpenUILang.parse(medium_src, schema)
       end},
      {"5. parse (Large 105 stmts)", 250,
       fn ->
         OpenUILang.parse(large_src, schema)
       end},
      {"6. evaluate_result (Medium 24 stmts)", 1_000,
       fn ->
         OpenUILang.evaluate_result(parsed_medium, %{cat: schema})
       end},
      {"7. parse + evaluate_result (Medium e2e)", 1_000,
       fn ->
         res = OpenUILang.parse(medium_src, schema)
         OpenUILang.evaluate_result(res, %{cat: schema})
       end},
      {"8. parse + evaluate_result w/ @Each (Large 105 stmts)", 200,
       fn ->
         res = OpenUILang.parse(large_src, schema)
         OpenUILang.evaluate_result(res, %{cat: schema})
       end},
      {"9. Streaming push_chunk x#{length(medium_chunks)} (Medium 32B chunks)", 200,
       fn ->
         sp = OpenUILang.stream_parser(schema)
         total = length(medium_chunks)

         Enum.with_index(medium_chunks, 1)
         |> Enum.reduce(sp, fn {chunk, idx}, acc_sp ->
           {_res, next_sp} = OpenUILang.push_chunk(acc_sp, chunk, idx == total)
           next_sp
         end)
       end},
      {"10. Streaming push_chunk x#{length(large_chunks)} (Large 48B chunks)", 40,
       fn ->
         sp = OpenUILang.stream_parser(schema)
         total = length(large_chunks)

         Enum.with_index(large_chunks, 1)
         |> Enum.reduce(sp, fn {chunk, idx}, acc_sp ->
           {_res, next_sp} = OpenUILang.push_chunk(acc_sp, chunk, idx == total)
           next_sp
         end)
       end},
      {"11. merge_statements (Medium 24 stmts + 4-stmt patch)", 1_000,
       fn ->
         OpenUILang.merge_statements(medium_src, patch_src)
       end},
      {"12. merge_statements (Large 105 stmts + 4-stmt patch)", 250,
       fn ->
         OpenUILang.merge_statements(large_src, patch_src)
       end},
      {"13. demux + parse_symbols (TUI 1Hz path, Medium)", 1_000,
       fn ->
         %{code: code} = OpenUILang.demux(mixed_chat_src)
         OpenUILang.parse_symbols(code)
       end},
      {"14. json_to_openui (Roundtrip Serializer, Medium)", 1_000,
       fn ->
         OpenUILang.json_to_openui(evaluated_medium["tree"], schema)
       end}
    ]

    if "--profile-only" in System.argv() do
      run_eprof_profile(schema, medium_src, large_src, medium_chunks, patch_src)
      []
    else
      IO.puts(
        String.pad_trailing("Benchmark Scenario", 54) <>
          String.pad_leading("Avg (µs)", 10) <>
          String.pad_leading("P50 (µs)", 10) <>
          String.pad_leading("P99 (µs)", 10) <>
          String.pad_leading("Ops/sec", 12) <>
          String.pad_leading("Mem/op", 12)
      )

      IO.puts(String.duplicate("─", 108))

      results =
        Enum.map(benchmarks, fn {label, iters, fun} ->
          stats = measure(iters, fun)

          IO.puts(
            String.pad_trailing(label, 54) <>
              String.pad_leading(format_num(stats.avg_us), 10) <>
              String.pad_leading(format_num(stats.p50_us), 10) <>
              String.pad_leading(format_num(stats.p99_us), 10) <>
              String.pad_leading(format_int(round(stats.ops_per_sec)), 12) <>
              String.pad_leading(format_bytes(stats.mem_bytes), 12)
          )

          {label, stats}
        end)

      IO.puts(String.duplicate("─", 108))
    if "--profile" in System.argv() or "--profile-only" in System.argv() do
      run_eprof_profile(schema, medium_src, large_src, medium_chunks, patch_src)
    end

    results
    end
  end

  defp measure(iters, fun) do
    # Warmup
    for _ <- 1..min(20, max(2, div(iters, 10))), do: fun.()

    # Measure memory of a single isolated execution in a spawned process
    mem_bytes = measure_memory(fun)

    times =
      for _ <- 1..iters do
        t0 = System.monotonic_time(:nanosecond)
        _ = fun.()
        t1 = System.monotonic_time(:nanosecond)
        (t1 - t0) / 1000.0
      end
      |> Enum.sort()

    total_us = Enum.sum(times)
    avg_us = total_us / iters
    p50_us = Enum.at(times, div(iters, 2))
    p99_us = Enum.at(times, min(iters - 1, trunc(iters * 0.99)))
    ops_per_sec = if avg_us > 0, do: 1_000_000.0 / avg_us, else: 0.0

    %{
      avg_us: avg_us,
      p50_us: p50_us,
      p99_us: p99_us,
      ops_per_sec: ops_per_sec,
      mem_bytes: mem_bytes
    }
  end

  defp measure_memory(fun) do
    parent = self()

    spawn(fn ->
      :erlang.garbage_collect()
      {:memory, before_mem} = Process.info(self(), :memory)
      res = fun.()
      {:memory, after_mem} = Process.info(self(), :memory)
      # Keep `res` live until after `Process.info`
      _ = :erlang.phash2(res)
      send(parent, {:mem_used, max(0, after_mem - before_mem)})
    end)

    receive do
      {:mem_used, bytes} -> bytes
    after
      5_000 -> 0
    end
  end

  defp run_eprof_profile(schema, _medium_src, large_src, medium_chunks, patch_src) do
    Mix.ensure_application!(:tools)

    profile_scenario("Profile A: Batch parse + evaluate_result (Large 105 stmts x10)", fn ->
      for _ <- 1..10 do
        res = OpenUILang.parse(large_src, schema)
        _ = OpenUILang.evaluate_result(res, %{cat: schema})
      end
    end)

    profile_scenario("Profile B: Streaming push_chunk (Medium 46 chunks x10)", fn ->
      for _ <- 1..10 do
        sp = OpenUILang.stream_parser(schema)
        total = length(medium_chunks)

        Enum.with_index(medium_chunks, 1)
        |> Enum.reduce(sp, fn {chunk, idx}, acc_sp ->
          {_res, next_sp} = OpenUILang.push_chunk(acc_sp, chunk, idx == total)
          next_sp
        end)
      end
    end)

    profile_scenario("Profile C: merge_statements (Large 105 stmts x10)", fn ->
      for _ <- 1..10 do
        _ = OpenUILang.merge_statements(large_src, patch_src)
      end
    end)
  end

  defp profile_scenario(title, fun) do
    IO.puts("\n======================================================================")
    IO.puts("  :eprof — #{title}")
    IO.puts("======================================================================")

    :eprof.start()
    :eprof.start_profiling([self()])
    fun.()
    :eprof.stop_profiling()

    log_path = Path.join(System.tmp_dir!(), "openui_lang_eprof.log")
    File.rm_rf(log_path)
    :eprof.log(String.to_charlist(log_path))
    :eprof.analyze(:total)
    :eprof.stop()

    case File.read(log_path) do
      {:ok, content} ->
        lines =
          content
          |> String.split("\n")
          |> Enum.filter(fn line ->
            String.contains?(line, "OpenUILang") or
              String.contains?(line, "FUNCTION") or
              String.contains?(line, ":ets") or
              String.contains?(line, "Regex") or
              String.contains?(line, "String.") or
              String.contains?(line, ":binary") or
              String.contains?(line, "Enum.") or
              String.contains?(line, "Map.")
          end)
          |> Enum.take(-25)

        IO.puts(Enum.join(lines, "\n"))

      _ ->
        :ok
    end
  end

  defp chunk_string(bin, size) when byte_size(bin) <= size, do: [bin]

  defp chunk_string(bin, size) do
    <<part::binary-size(size), rest::binary>> = bin
    [part | chunk_string(rest, size)]
  end

  defp format_num(f), do: :erlang.float_to_binary(f * 1.0, decimals: 1)

  defp format_int(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp format_bytes(b) when b >= 1_048_576, do: "#{Float.round(b / 1_048_576, 2)} MB"
  defp format_bytes(b) when b >= 1024, do: "#{Float.round(b / 1024, 1)} KB"
  defp format_bytes(b), do: "#{b} B"

  defp build_small_program do
    """
    $selected = "t1"
    root = Stack([header, body, btn])
    header = Text("Cluster Overview", "h1")
    body = Card("Active Nodes", [Text("All 9 nodes healthy")])
    btn = Button("Refresh", @Set($selected, "t2"))
    """
  end

  defp build_medium_program do
    """
    $selected_env = "prod"
    $auto_heal = true
    $min_latency = 10
    root = Stack([header, kpi_row, main_grid, details_card, action_row])
    header = Card("Memcached & BEAM Live Telemetry", [sub_text, status_badge])
    sub_text = Text("127.0.0.1:11211 • Polling at 1Hz with 0 LLM tokens")
    status_badge = Badge("HEALTHY", "success")
    kpi_row = Stack([kpi_ops, kpi_hit, kpi_mem], "row")
    kpi_ops = Card("1. Service & Conns", [Text("1,426 ops/s"), Text("3 / 1,024 conns")])
    kpi_hit = Card("2. Cache Hit Rate", [Text("83.24%"), Text("595,167 hits / 119,859 misses")])
    kpi_mem = Card("3. Memory & Items", [Text("6.67 MB / 128.0 MB"), Text("1,216 active items")])
    main_grid = Stack([perf_card, net_card], "row")
    perf_card = Card("Service & Cache Performance", [
      Text("PID 1426 • v1.6.45 • Up 15d 9h"),
      Text("GET: 715,026 • SET: 66,799 • Flush: 286")
    ])
    net_card = Card("Memory Health & Network I/O", [
      Text("Evictions: 2,209 (0/s) • OOM: 0"),
      Text("Net In: 271.21 MB • Net Out: 3.89 GB")
    ])
    details_card = Card("Slab Class Distribution", [
      Text("Slab 1 (96B) : 812 items • 1 page • 7.4% util"),
      Text("Slab 4 (192B): 240 items • 1 page • 4.4% util"),
      Text("Slab 20 (64K): 164 items • 11 pages • 93.1% util")
    ])
    action_row = Stack([btn_diag, btn_reset], "row")
    btn_diag = Button("Diagnose Slab " + $selected_env, @ToAssistant("Analyze slab evictions for " + $selected_env))
    btn_reset = Button("Reset Filter", @Reset($selected_env, $auto_heal))
    """
  end

  defp build_large_program(n) do
    cards =
      for i <- 1..n do
        """
        card_#{i} = Card("Node #" + #{i} + " (" + $selected_env + ")", [
          Text("Host: node-#{i}.internal • CPU: " + (#{rem(i * 7, 95)} + 5) + "%"),
          Badge(#{rem(i, 5) == 0} ? "WARN" : "OK", #{rem(i, 5) == 0} ? "warning" : "success"),
          Button("Inspect Node #{i}", @Set($selected_node, "node-#{i}"))
        ])
        """
      end
      |> Enum.join("\n")

    refs = Enum.map_join(1..n, ", ", &"card_#{&1}")

    """
    $selected_env = "prod"
    $selected_node = "node-1"
    rows = [{id: "n1", cpu: 42}, {id: "n2", cpu: 88}, {id: "n3", cpu: 19}, {id: "n4", cpu: 64}]
    sorted_rows = @Sort(@Filter(rows, "cpu", ">", 20), "cpu", "desc")
    summary_list = Stack(@Each(sorted_rows, "r", Card(r.id, [Text("CPU: " + r.cpu + "%")])))
    root = Stack([summary_list, grid])
    grid = Stack([#{refs}])
    #{cards}
    """
  end

  defp build_patch_program do
    """
    kpi_ops = Card("1. Service & Conns (Updated)", [Text("2,180 ops/s"), Text("8 / 1,024 conns")])
    kpi_hit = Card("2. Cache Hit Rate (Updated)", [Text("91.40%"), Text("812,000 hits")])
    new_alert = Badge("SLAB 20 PRESSURE", "warning")
    header = Card("Memcached & BEAM Live Telemetry", [sub_text, status_badge, new_alert])
    """
  end

  defp build_mixed_chat(code) do
    """
    I have updated the Memcached & BEAM Live Telemetry dashboard with 5 structured panels and real-time 1Hz bindings:

    ```openui
    #{code}
    ```

    Press `Tab` or `F2` to interact with the live slab selector.
    """
  end
end

OpenUILang.Bench.run()
