defmodule LoggerIexBackend.MixProject do
  use Mix.Project

  def project do
    [
      app: :logger_iex_backend,
      version: "1.0.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:excoveralls, "~> 0.11", only: :test}
    ]
  end

  def docs do
    [
      main: "LoggerIexBackend",
      extras: ["README.md"]
    ]
  end
end
