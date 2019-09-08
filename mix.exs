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
      package: package(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test],
      name: "LoggerIexBackend",
      description: "A Logger Backend for IEx interactive sessions."
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:excoveralls, "~> 0.11", only: :test}
    ]
  end

  defp docs do
    [
      main: "LoggerIexBackend",
      extras: ["README.md"]
    ]
  end

  defp package() do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/alvivi/logger_iex_backend"}
    ]
  end
end
