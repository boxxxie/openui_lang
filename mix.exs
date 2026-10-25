defmodule OpenUILang.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :openui_lang,
      version: @version,
      elixir: "~> 1.18",
      compilers: [:zig_nif] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      description:
        "Elixir parser, streaming engine, evaluator, and prompt generator for OpenUI Lang 1.0.",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp deps do
    []
  end

  defp package do
    [
      files: ~w(lib native .formatter.exs mix.exs README.md usage-rules.md),
      licenses: ["MIT"]
    ]
  end

  defp aliases do
    [
      precommit: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test"
      ]
    ]
  end
end

defmodule Mix.Tasks.Compile.ZigNif do
  use Mix.Task.Compiler

  @impl true
  def run(_args) do
    priv_dir = Path.expand("priv")
    File.mkdir_p!(priv_dir)
    so_path = Path.join(priv_dir, "openui_nif.so")
    zig_src = Path.expand("native/openui_nif.zig")
    c_src = Path.expand("native/nif_entry.c")

    if needs_compile?(so_path, [zig_src, c_src]) do
      case System.find_executable("zig") do
        nil ->
          Mix.shell().error("zig compiler not found in PATH; skipping openui_nif.so build")

        zig ->
          erts_include =
            Path.join([
              to_string(:code.root_dir()),
              "erts-#{:erlang.system_info(:version)}",
              "include"
            ])

          Mix.shell().info("Compiling Zig NIF (priv/openui_nif.so)...")

          {output, status} =
            System.cmd(
              zig,
              [
                "build-lib",
                "-dynamic",
                "-O",
                "ReleaseFast",
                "-fstrip",
                zig_src,
                c_src,
                "-I#{erts_include}",
                "-lc",
                "-femit-bin=#{so_path}"
              ],
              stderr_to_stdout: true
            )

          if status != 0 do
            Mix.raise("Failed to compile Zig NIF:\n#{output}")
          end
      end
    end

    Mix.Project.build_structure()
    {:ok, []}
  end

  defp needs_compile?(target, sources) do
    case File.stat(target) do
      {:ok, %{mtime: target_mtime}} ->
        Enum.any?(sources, fn src ->
          case File.stat(src) do
            {:ok, %{mtime: src_mtime}} -> src_mtime > target_mtime
            _ -> true
          end
        end)

      _ ->
        true
    end
  end
end
