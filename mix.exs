defmodule OpenUILang.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :openui_lang,
      version: @version,
      elixir: "~> 1.18",
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
      files: ~w(lib .formatter.exs mix.exs README.md usage-rules.md),
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
